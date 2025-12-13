use std::collections::{HashMap, HashSet};
use xxhash_rust::xxh3::xxh3_64;
use regex::Regex;

/// DanmakuMask: 滑动窗口 + 分桶 + 频控
#[flutter_rust_bridge::frb(opaque)]
pub struct DanmakuMask {
    base_window_ms: u64,
    bucket_count: usize,
    use_normalization: bool,
    use_frequency_control: bool,
    max_frequency: u32,
    adaptive_window: bool,

    window_ms: u64,
    bucket_size_ms: u64,

    current_bucket: usize,
    last_shift_ms: u64,

    buckets: Vec<HashSet<u64>>, // 每个桶存储哈希
    freq_map: HashMap<u64, u32>, // 总频次
    // normalization
    norm_re_space: Option<Regex>,
    norm_re_punct: Option<Regex>,
}

impl DanmakuMask {
    pub fn new(
        base_window_ms: u64,
        bucket_count: usize,
        use_normalization: bool,
        use_frequency_control: bool,
        max_frequency: u32,
        adaptive_window: bool,
    ) -> Self {
        let window_ms = base_window_ms;
        let bucket_size_ms = window_ms / (bucket_count as u64).max(1);

        let norm_space = if use_normalization {
            Some(Regex::new(r"\s+").unwrap())
        } else {
            None
        };
        let norm_punct = if use_normalization {
            Some(Regex::new(r"[~!！?？,.，。]").unwrap())
        } else {
            None
        };

        Self {
            base_window_ms,
            bucket_count,
            use_normalization,
            use_frequency_control,
            max_frequency,
            adaptive_window,
            window_ms,
            bucket_size_ms,
            current_bucket: 0,
            last_shift_ms: 0,
            buckets: (0..bucket_count).map(|_| HashSet::with_capacity(128)).collect(),
            freq_map: HashMap::with_capacity(1024),
            norm_re_space: norm_space,
            norm_re_punct: norm_punct,
        }
    }

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
        // 如果尚未初始化 last_shift_ms 则设置为 now_ms
        if self.last_shift_ms == 0 {
            self.last_shift_ms = now_ms;
            return;
        }

        while now_ms.saturating_sub(self.last_shift_ms) >= self.bucket_size_ms {
            self.last_shift_ms = self.last_shift_ms.saturating_add(self.bucket_size_ms);
            // advance bucket
            self.current_bucket = (self.current_bucket + 1) % self.bucket_count;
            // clear expired bucket
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

    fn adapt_window(&mut self) {
        if !self.adaptive_window { return; }
        let total_items: usize = self.buckets.iter().map(|b| b.len()).sum();
        if total_items > 300 {
            self.window_ms = std::cmp::max(self.base_window_ms / 2, 1500);
        } else if total_items < 50 {
            self.window_ms = self.base_window_ms;
        }
        self.bucket_size_ms = self.window_ms / (self.bucket_count as u64).max(1);
    }

    /// 处理一批文本，返回 Vec<u8>：1 表示允许，0 表示被屏蔽
    pub fn allow_list_batch(&mut self, texts: &[String], now_ms: u64) -> Vec<u8> {
        self.shift_if_needed(now_ms);
        self.adapt_window();

        let mut results: Vec<u8> = Vec::with_capacity(texts.len());
        for t in texts.iter() {
            let normalized = self.normalize(t);
            let hash = xxh3_64(normalized.as_bytes());

            // freq_map 包含 hash->窗口内出现过
            let mut is_allowed = true;
            if self.freq_map.contains_key(&hash) {
                is_allowed = false;
            }

            if is_allowed && self.use_frequency_control {
                let freq = *self.freq_map.get(&hash).unwrap_or(&0u32);
                if freq >= self.max_frequency {
                    is_allowed = false;
                }
            }

            if is_allowed {
                // 插入当前桶并更新频次
                self.buckets[self.current_bucket].insert(hash);
                *self.freq_map.entry(hash).or_insert(0) += 1;
            }
            results.push(if is_allowed { 1 } else { 0 });
        }
        results
    }

    pub fn reset(&mut self) {
        for b in &mut self.buckets {
            b.clear();
        }
        self.freq_map.clear();
        self.current_bucket = 0;
        self.last_shift_ms = 0;
        self.window_ms = self.base_window_ms;
        self.bucket_size_ms = self.window_ms / (self.bucket_count as u64).max(1);
    }
    // todo : 或许可以用google-SimHash来处理近似语义
}

