#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

use std::sync::Mutex;
use crate::api::danmaku_mask::DanmakuMask;

lazy_static::lazy_static! {
    static ref SINGLETON_MASK: Mutex<DanmakuMask> = Mutex::new(DanmakuMask::new(15000, 15, false, true, 3, true));
}
#[flutter_rust_bridge::frb(sync)]
pub fn allow_list_batch_global(texts: Vec<String>, now_ms: u64) -> Vec<u8> {
    let mut mask = SINGLETON_MASK.lock().unwrap();
    mask.allow_list_batch(&texts, now_ms)
}