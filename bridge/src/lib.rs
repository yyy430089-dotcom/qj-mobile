//! iOS 的 C ABI 边界；句柄注册表避免已销毁会话被重复使用。
mod action;
mod frame;
mod session;

use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::{Mutex, OnceLock};
use std::sync::atomic::{AtomicU64, Ordering};

use action::Action;
use frame::Frame;
use session::Session;

fn sessions() -> &'static Mutex<HashMap<u64, Session>> {
    static SESSIONS: OnceLock<Mutex<HashMap<u64, Session>>> = OnceLock::new();
    SESSIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// # Safety
/// 非空路径指针必须指向有效的 NUL 结尾 UTF-8 字符串。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qjm_create(dict: *const c_char, gloss: *const c_char) -> u64 {
    catch_unwind(AssertUnwindSafe(|| {
        if dict.is_null() || gloss.is_null() { return 0; }
        let Ok(dict) = (unsafe { CStr::from_ptr(dict) }).to_str() else { return 0; };
        let Ok(gloss) = (unsafe { CStr::from_ptr(gloss) }).to_str() else { return 0; };
        let Ok(session) = Session::from_paths(dict, gloss) else { return 0; };
        static NEXT: AtomicU64 = AtomicU64::new(1);
        let id = NEXT.fetch_add(1, Ordering::Relaxed);
        sessions().lock().unwrap_or_else(|e| e.into_inner()).insert(id, session);
        id
    })).unwrap_or(0)
}

/// # Safety
/// JSON 指针必须指向有效的 NUL 结尾字符串，返回值只释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qjm_dispatch(id: u64, command: *const c_char) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if command.is_null() { return Frame::error("Empty command"); }
        let bytes = unsafe { CStr::from_ptr(command) }.to_bytes();
        let Ok(action) = serde_json::from_slice::<Action>(bytes) else {
            return Frame::error("Invalid command");
        };
        let mut registry = sessions().lock().unwrap_or_else(|e| e.into_inner());
        match registry.get_mut(&id) {
            Some(session) => session.apply(action),
            None => Frame::error("Session unavailable"),
        }
    }));
    let frame = match result {
        Ok(frame) => frame,
        Err(_) => {
            // 发生 panic 的引擎不再复用，让 Swift 显示可恢复的故障状态。
            sessions().lock().unwrap_or_else(|e| e.into_inner()).remove(&id);
            Frame::error("Input engine recovered from a failure")
        }
    };
    let json = serde_json::to_string(&frame).unwrap_or_else(|_| "{\"error\":\"Encoding failure\"}".into());
    CString::new(json).expect("JSON has no literal NUL").into_raw()
}

#[unsafe(no_mangle)]
pub extern "C" fn qjm_destroy(id: u64) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        sessions().lock().unwrap_or_else(|e| e.into_inner()).remove(&id);
    }));
}

/// # Safety
/// value 必须为本桥接层返回、尚未释放的指针，或空指针。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qjm_string_free(value: *mut c_char) {
    if !value.is_null() { drop(unsafe { CString::from_raw(value) }); }
}

#[cfg(test)]
mod tests;
