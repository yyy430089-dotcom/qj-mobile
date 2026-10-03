//! 一次动作的文本副作用与候选快照，不携带输入日志或应用上下文。
use serde::Serialize;

#[derive(Debug, Default, Serialize)]
pub(crate) struct Frame {
    pub revision: u64,

    pub input: String,

    pub preedit: String,

    pub candidates: Vec<CandidateView>,

    pub committed: String,

    pub delete_backward: bool,

    pub english: bool,

    pub error: Option<String>,

    pub warning: Option<String>,
}

impl Frame {
    pub fn error(message: &str) -> Self {
        Self { error: Some(message.into()), ..Self::default() }
    }
}

#[derive(Debug, Serialize)]
pub(crate) struct CandidateView {
    pub text: String,

    pub annotation: Option<String>,
}
