//! 构建时把可检查的 TSV 源数据打成只读 mmap 数据，手机不解析大表。
use qingjian_core::Language;
use qingjian_dictionary::Dictionary;
use qingjian_format::Metadata;
use qingjian_translate::Glossary;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let source = Path::new(args.get(1).map(String::as_str).unwrap_or("DataSource"));
    let output = Path::new(args.get(2).map(String::as_str).unwrap_or("build/Data"));
    std::fs::create_dir_all(output)?;
    let metadata = Metadata {
        name: "简词基础词库".into(),
        license: "MIT AND Unicode-3.0; source-specific notices in Licenses".into(),
        attribution: "Qingjian contributors; THUNLP; Unicode, Inc.; see Licenses".into(),
        source: "https://github.com/qingjian-team/qingjian/tree/v0.1.4/assets/lexicon".into(),
        version: "v0.1.4".into(),
        generator: "qjmobile-pack-data 0.1.0".into(),
        ..Metadata::default()
    };
    Dictionary::from_path(source.join("dict.tsv"))?.write_qj(&output.join("dict.qj"), &metadata)?;
    Glossary::from_path(Language::English, source.join("glossary-en.tsv"))?.write_qj(
        &output.join("glossary-en.qj"),
        &Metadata {
            name: "基础词库英文释义".into(),
            license: "GPL-3.0-or-later".into(),
            source: "https://github.com/qingjian-team/qingjian/tree/v0.1.4/assets/glossary".into(),
            ..metadata
        },
    )?;
    println!(
        "Packed dictionary and English glossary into {}",
        output.display()
    );
    Ok(())
}
