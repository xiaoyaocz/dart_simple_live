use regex::Regex;
use std::collections::{HashMap, HashSet};
use xxhash_rust::xxh3::xxh3_64;

/// DanmakuMask: 滑动窗口 + 分桶 + 频控
#[flutter_rust_bridge::frb(opaque)]
pub struct DanmakuMask {
    base_window_ms: u32,     // 基础窗口（ms）
    bucket_count: u16,       // 桶数量
    max_frequency: u16,      // 最大允许频次

    use_normalization: bool,
    use_frequency_control: bool,
    adaptive_window: bool,

    // 运行时状态
    window_ms: u32,
    bucket_size_ms: u32,

    current_bucket: usize,  // Vec 索引
    last_shift_ms: u64,     // 上次滑动的时间戳（ms）

    buckets: Vec<HashSet<u64>>,  // 每个桶存 hash
    freq_map: HashMap<u64, u16>, // hash -> 频次

    norm_re_space: Option<Regex>,
    norm_re_punct: Option<Regex>,
}

#[flutter_rust_bridge::frb(sync)]
impl DanmakuMask {
    /// 构造函数（会生成 Dart 构造器）
    pub fn new(
        base_window_ms: u32,
        bucket_count: u16,
        use_normalization: bool,
        use_frequency_control: bool,
        max_frequency: u16,
        adaptive_window: bool,
    ) -> Self {
        let bucket_count_usize = bucket_count.max(1) as usize;
        let bucket_size_ms = base_window_ms / bucket_count.max(1) as u32;

        let norm_re_space = use_normalization
            .then(|| Regex::new(r"\s+").unwrap());
        let norm_re_punct = use_normalization
            .then(|| Regex::new(r"[~!！?？,.，。]").unwrap());

        Self {
            base_window_ms,
            bucket_count,
            max_frequency,
            use_normalization,
            use_frequency_control,
            adaptive_window,
            window_ms: base_window_ms,
            bucket_size_ms,
            current_bucket: 0,
            last_shift_ms: 0,
            buckets: (0..bucket_count_usize)
                .map(|_| HashSet::with_capacity(128))
                .collect(),
            freq_map: HashMap::with_capacity(1024),
            norm_re_space,
            norm_re_punct,
        }
    }

    /// 文本归一化
    fn normalize(&self, text: &str) -> String {
        if !self.use_normalization {
            return text.to_owned();
        }

        let mut s = text.trim().to_lowercase();
        if let Some(re) = &self.norm_re_space {
            s = re.replace_all(&s, "").to_string();
        }
        if let Some(re) = &self.norm_re_punct {
            s = re.replace_all(&s, "").to_string();
        }
        s
    }

    fn shift_if_needed(&mut self, now_ms: u64) {
        if self.last_shift_ms == 0 {
            self.last_shift_ms = now_ms;
            return;
        }

        while now_ms.saturating_sub(self.last_shift_ms)
            >= self.bucket_size_ms as u64
        {
            self.last_shift_ms += self.bucket_size_ms as u64;

            self.current_bucket =
                (self.current_bucket + 1) % self.bucket_count as usize;

            let expired = &mut self.buckets[self.current_bucket];
            for &hash in expired.iter() {
                if let Some(v) = self.freq_map.get_mut(&hash) {
                    if *v <= 1 {
                        self.freq_map.remove(&hash);
                    } else {
                        *v -= 1;
                    }
                }
            }
            expired.clear();
        }
    }

    /// 根据压力自适应窗口
    fn adapt_window(&mut self) {
        if !self.adaptive_window {
            return;
        }

        let total_items: usize =
            self.buckets.iter().map(|b| b.len()).sum();

        if total_items > 300 {
            self.window_ms = (self.base_window_ms / 2).max(1500);
        } else if total_items < 50 {
            self.window_ms = self.base_window_ms;
        }

        self.bucket_size_ms =
            self.window_ms / self.bucket_count.max(1) as u32;
    }



    /// 重置状态
    pub fn reset(&mut self) {
        for bucket in &mut self.buckets {
            bucket.clear();
        }
        self.freq_map.clear();
        self.current_bucket = 0;
        self.last_shift_ms = 0;
        self.window_ms = self.base_window_ms;
        self.bucket_size_ms =
            self.window_ms / self.bucket_count.max(1) as u32;
    }

    pub fn dispose(self){
        // 消费所有权
    }
}

#[flutter_rust_bridge::frb]
impl DanmakuMask {
    /// 批量判断是否允许
    /// 返回 Vec<u8>：1 = 允许，0 = 屏蔽
    pub fn allow_list_batch(
        &mut self,
        texts: Vec<String>,
        now_ms: u64,
    ) -> Vec<u8> {
        self.shift_if_needed(now_ms);
        self.adapt_window();

        let mut results = Vec::with_capacity(texts.len());

        for text in texts {
            let normalized = self.normalize(&text);
            let hash = xxh3_64(normalized.as_bytes());

            let mut allowed = true;

            if self.freq_map.contains_key(&hash) {
                allowed = false;
            }

            if allowed && self.use_frequency_control {
                let freq = *self.freq_map.get(&hash).unwrap_or(&0u16);
                if freq >= self.max_frequency {
                    allowed = false;
                }
            }

            if allowed {
                self.buckets[self.current_bucket].insert(hash);
                *self.freq_map.entry(hash).or_insert(0) += 1;
            }

            results.push(if allowed { 1 } else { 0 });
        }

        results
    }
}