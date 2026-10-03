//! Swift 发来的有限输入动作；候选使用查询版本防止过期点击。
use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub(crate) enum Action {
    Input { text: String },
    Backspace,
    Space,
    Enter,
    Raw,
    Cancel,
    Reset,
    ToggleLanguage,
    Snapshot,
    Annotate { revision: u64 },
    Choose { revision: u64, index: usize },
}
