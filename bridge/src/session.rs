//! 复用上游引擎的查询与上屏，不在手机界面重写拼音消耗或排序。
use qingjian_core::{Candidate, CandidateList, Engine, Language};
use qingjian_dictionary::Dictionary;
use qingjian_translate::Glossary;

use crate::action::Action;
use crate::frame::{CandidateView, Frame};

const MAX_INPUT: usize = 64;
const MAX_CANDIDATES: usize = 60;

pub(crate) struct Session {
    engine: Engine,

    candidates: Vec<Candidate>,

    preedit: String,

    revision: u64,

    warning: Option<String>,
}

impl Session {
    pub fn from_paths(dict: &str, glossary: &str) -> Result<Self, String> {
        let dictionary = Dictionary::from_path(dict).map_err(|e| e.to_string())?;
        let mut session = Self::new(dictionary);
        match Glossary::from_path(Language::English, glossary) {
            Ok(table) => session.engine.set_translator(Box::new(table)),
            Err(_) => session.warning = Some("英文释义暂不可用，中文输入仍可使用".into()),
        }
        Ok(session)
    }

    pub fn new(dictionary: Dictionary) -> Self {
        let mut engine = Engine::new(dictionary);
        engine.set_learning(false);
        engine.set_private(true);
        engine.set_full_width_punctuation(true);
        Self { engine, candidates: Vec::new(), preedit: String::new(), revision: 0, warning: None }
    }

    fn refresh(&mut self) {
        self.revision += 1;
        self.candidates.clear();
        self.preedit = self.engine.composition().text().to_owned();
        if self.engine.composition().is_empty() { return; }
        if let Ok(mut query) = self.engine.query() {
            self.preedit = query.marked_text();
            query.candidates.items.truncate(MAX_CANDIDATES);
            self.candidates = query.candidates.items;
        }
    }

    fn commit_first(&mut self) -> String {
        match self.candidates.first().cloned() {
            Some(candidate) => self.engine.commit(&candidate),
            None => self.engine.take_raw(),
        }
    }

    fn finish_composition(&mut self) -> String {
        let mut result = String::new();
        if !self.engine.composition().is_empty() { self.refresh(); }
        for _ in 0..MAX_INPUT {
            if self.engine.composition().is_empty() { break; }
            let before = self.engine.composition().text().len();
            result.push_str(&self.commit_first());
            self.refresh();
            if self.engine.composition().text().len() >= before {
                result.push_str(&self.engine.take_raw());
                break;
            }
        }
        result
    }

    pub fn apply(&mut self, action: Action) -> Frame {
        let mut committed = String::new();
        let mut delete_backward = false;
        let mut error = None;
        let mut changed = true;
        match action {
            Action::Input { text } => {
                if text.chars().count() > MAX_INPUT {
                    error = Some("Input action is too long".into());
                    changed = false;
                } else {
                    for c in text.chars() {
                        if !self.engine.english_mode() && (c.is_ascii_lowercase() || c == '\'') {
                            if self.engine.composition().text().len() >= MAX_INPUT {
                                committed.push_str(&self.finish_composition());
                            }
                            self.engine.push(c);
                        } else {
                            committed.push_str(&self.finish_composition());
                            if !self.engine.english_mode() {
                                if let Some(punctuation) = self.engine.punctuate(c) {
                                    committed.push_str(punctuation);
                                    continue;
                                }
                            }
                            committed.push(c);
                            self.engine.note_passthrough(c);
                        }
                    }
                }
            }
            Action::Backspace => {
                if !self.engine.backspace() {
                    delete_backward = true;
                    self.engine.note_backspace();
                }
            }
            Action::Space => {
                if self.engine.composition().is_empty() { committed.push(' '); }
                else { committed = self.commit_first(); }
            }
            Action::Enter => {
                if self.engine.composition().is_empty() { committed.push('\n'); }
                else { committed = self.finish_composition(); }
            }
            Action::Raw => committed = self.engine.take_raw(),
            Action::Cancel => {
                self.engine.clear();
                self.engine.break_chain();
            }
            Action::Reset => self.engine.discard_input(),
            Action::ToggleLanguage => {
                committed = self.finish_composition();
                self.engine.set_english_mode(!self.engine.english_mode());
                self.engine.break_chain();
            }
            Action::Choose { revision, index } => {
                if revision != self.revision {
                    error = Some("Candidate has expired".into());
                    changed = false;
                } else if let Some(candidate) = self.candidates.get(index).cloned() {
                    committed = self.engine.commit(&candidate);
                } else {
                    error = Some("Candidate index is invalid".into());
                    changed = false;
                }
            }
            Action::Annotate { revision } => {
                changed = false;
                if revision == self.revision {
                    let mut list = CandidateList { items: std::mem::take(&mut self.candidates) };
                    self.engine.annotate(&mut list);
                    self.candidates = list.items;
                }
            }
            Action::Snapshot => changed = false,
        }
        if changed { self.refresh(); }
        Frame {
            revision: self.revision,
            input: self.engine.composition().text().to_owned(),
            preedit: self.preedit.clone(),
            candidates: self.candidates.iter().map(|c| CandidateView {
                text: c.text.clone(),
                annotation: c.translation.as_ref().and_then(|t| t.senses().first()).map(|s| {
                    s.part_of_speech.map_or_else(|| s.text.clone(), |p| format!("{} {}", p, s.text))
                }),
            }).collect(),
            committed, delete_backward,
            english: self.engine.english_mode(),
            error, warning: self.warning.clone(),
        }
    }
}
