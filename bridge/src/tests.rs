//! 覆盖移植边界：部分选词、查询版本、缺译词与 C ABI 生命周期。
use std::ffi::{CStr, CString};
use qingjian_dictionary::Dictionary;
use qingjian_core::Language;
use qingjian_translate::Glossary;

use crate::action::Action;
use crate::session::Session;
use crate::{qjm_create, qjm_destroy, qjm_dispatch, qjm_string_free};

fn session() -> Session {
    Session::new(Dictionary::parse("你\tni\t1000\n好\thao\t900\n你好\tni hao\t2000\n开发\tkai fa\t3000\n者\tzhe\t500\n").unwrap())
}

#[test]
fn full_pinyin_and_initials_keep_chinese_candidates() {
    for input in ["kaifa", "kf", "kaif"] {
        let mut s = session();
        let frame = s.apply(Action::Input { text: input.into() });
        assert!(frame.candidates.iter().any(|c| c.text == "开发"), "{input}");
    }
}

#[test]
fn choosing_prefix_preserves_remaining_pinyin() {
    let mut s = session();
    let frame = s.apply(Action::Input { text: "kaifazhe".into() });
    let index = frame.candidates.iter().position(|c| c.text == "开发").unwrap();
    let chosen = s.apply(Action::Choose { revision: frame.revision, index });
    assert_eq!(chosen.committed, "开发");
    assert_eq!(chosen.input, "zhe");
    let final_frame = s.apply(Action::Space);
    assert_eq!(final_frame.committed, "者");
    assert!(final_frame.input.is_empty());
}

#[test]
fn stale_candidate_and_annotation_cannot_commit_new_input() {
    let mut s = session();
    let old = s.apply(Action::Input { text: "ni".into() });
    let current = s.apply(Action::Input { text: "hao".into() });
    let rejected = s.apply(Action::Choose { revision: old.revision, index: 0 });
    assert!(rejected.committed.is_empty());
    assert!(rejected.error.is_some());
    assert_eq!(rejected.input, "nihao");
    let late = s.apply(Action::Annotate { revision: old.revision });
    assert_eq!(late.revision, current.revision);
    assert_eq!(late.input, current.input);
}

#[test]
fn backspace_cancel_raw_and_language_switch_have_ordered_effects() {
    let mut s = session();
    s.apply(Action::Input { text: "nihao".into() });
    assert_eq!(s.apply(Action::Backspace).input, "niha");
    assert!(s.apply(Action::Cancel).input.is_empty());
    assert!(s.apply(Action::Backspace).delete_backward);
    s.apply(Action::Input { text: "nihao".into() });
    assert_eq!(s.apply(Action::Raw).committed, "nihao");
    assert!(s.apply(Action::ToggleLanguage).english);
    assert_eq!(s.apply(Action::Input { text: "Hello".into() }).committed, "Hello");
}

#[test]
fn punctuation_flushes_composition_and_return_does_not_double_insert() {
    let mut s = session();
    let frame = s.apply(Action::Input { text: "kaifa,".into() });
    assert_eq!(frame.committed, "开发，");
    s.apply(Action::Input { text: "nihao".into() });
    assert_eq!(s.apply(Action::Enter).committed, "你好");
    assert_eq!(s.apply(Action::Enter).committed, "\n");
}

#[test]
fn mmap_data_roundtrip_and_missing_glossary_are_nonfatal() {
    let folder = std::env::temp_dir().join(format!("qjmobile-tests-{}", std::process::id()));
    std::fs::create_dir_all(&folder).unwrap();
    let dict = Dictionary::parse("开发\tkai fa\t1000\n").unwrap();
    let gloss = Glossary::parse(Language::English, "开发\tn. development\n").unwrap();
    dict.write_qj(&folder.join("dict.qj"), &Default::default()).unwrap();
    gloss.write_qj(&folder.join("gloss.qj"), &Default::default()).unwrap();
    let mut s = Session::from_paths(folder.join("dict.qj").to_str().unwrap(), folder.join("gloss.qj").to_str().unwrap()).unwrap();
    let f = s.apply(Action::Input { text: "kaifa".into() });
    assert!(f.candidates[0].annotation.is_none());
    let annotated = s.apply(Action::Annotate { revision: f.revision });
    assert!(annotated.candidates.iter().any(|c| c.annotation.as_deref() == Some("n. development")));
    drop(s);
    let mut no_gloss = Session::from_paths(folder.join("dict.qj").to_str().unwrap(), folder.join("missing.qj").to_str().unwrap()).unwrap();
    let f = no_gloss.apply(Action::Input { text: "kaifa".into() });
    assert!(f.warning.is_some());
    assert!(f.candidates.iter().any(|c| c.text == "开发"));
    drop(no_gloss);
    std::fs::remove_dir_all(folder).unwrap();
}

#[test]
fn c_abi_invalid_json_and_destroyed_handles_return_errors() {
    let command = CString::new("{\"action\":\"snapshot\"}").unwrap();
    unsafe {
        assert_eq!(qjm_create(std::ptr::null(), std::ptr::null()), 0);
        let pointer = qjm_dispatch(u64::MAX, command.as_ptr());
        let frame: serde_json::Value = serde_json::from_slice(CStr::from_ptr(pointer).to_bytes()).unwrap();
        assert!(frame["error"].is_string());
        qjm_string_free(pointer);
        qjm_destroy(u64::MAX);
        qjm_string_free(std::ptr::null_mut());
    }
}

#[test]
fn bundled_dictionary_and_glossary_cover_expected_words() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let mut s = Session::from_paths(root.join("DataSource/dict.tsv").to_str().unwrap(), root.join("DataSource/glossary-en.tsv").to_str().unwrap()).unwrap();
    for input in ["kaifa", "nihao", "xuexi", "zhongguo", "kf"] {
        s.apply(Action::Reset);
        let frame = s.apply(Action::Input { text: input.into() });
        assert!(!frame.candidates.is_empty(), "No candidates for {input}");
        let frame = s.apply(Action::Annotate { revision: frame.revision });
        assert!(frame.candidates.iter().any(|c| c.annotation.is_some()), "No glossary for {input}");
    }
}
