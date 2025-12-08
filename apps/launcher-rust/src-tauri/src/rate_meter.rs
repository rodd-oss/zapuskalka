use std::collections::VecDeque;
use std::time::{Duration, Instant};

pub struct RateMeter {
    // Configuration
    update_interval: Duration,

    // Raw data storage (last second only)
    values: VecDeque<(Instant, u64)>,

    // Current state
    last_update: Instant,
    smoothed_rate: f64,

    // Internal statistics
    total_sum: u64,
}

impl RateMeter {
    /// Creates a new SmoothedAverage with the specified update interval
    pub fn new(update_interval: Duration) -> Self {
        Self {
            update_interval,
            values: VecDeque::new(),
            last_update: Instant::now(),
            smoothed_rate: 0.0,
            total_sum: 0,
        }
    }

    /// Adds a new value at the current time
    pub fn add_value(&mut self, value: u64) {
        let now = Instant::now();

        // Clean up old values (older than 1 second)
        self.cleanup_old_values(now);

        // Add new value
        self.values.push_back((now, value));
        self.total_sum += value;

        // Update rate if update_interval has passed
        self.update_smoothed_rate(now);
    }

    /// Gets the current smoothed rate (per second)
    pub fn get_rate(&self) -> f64 {
        self.smoothed_rate
    }

    /// Gets the current raw rate (per second) without smoothing
    pub fn get_raw_rate(&self) -> f64 {
        let now = Instant::now();

        // Calculate current rate from the last second's data
        if let Some((oldest, _)) = self.values.front() {
            let time_window = now.duration_since(*oldest).as_secs_f64().max(1e-9);
            let count = self.values.len() as f64;

            if count > 0.0 {
                self.total_sum as f64 / time_window
            } else {
                0.0
            }
        } else {
            0.0
        }
    }

    /// Updates the smoothed rate value
    fn update_smoothed_rate(&mut self, now: Instant) {
        if now.duration_since(self.last_update) >= self.update_interval {
            let raw_rate = self.get_raw_rate();

            // Apply exponential smoothing
            // Weight factor based on update_interval (smaller interval = more smoothing)
            let alpha = 0.3; // You can adjust this or make it configurable

            if self.smoothed_rate == 0.0 {
                // First update
                self.smoothed_rate = raw_rate;
            } else {
                self.smoothed_rate = alpha * raw_rate + (1.0 - alpha) * self.smoothed_rate;
            }

            self.last_update = now;
        }
    }

    /// Removes values older than 1 second
    fn cleanup_old_values(&mut self, now: Instant) {
        let one_second_ago = now.checked_sub(Duration::from_secs(1)).unwrap_or(now);

        while let Some(&(timestamp, value)) = self.values.front() {
            if timestamp < one_second_ago {
                self.values.pop_front();
                self.total_sum -= value;
            } else {
                break;
            }
        }
    }
}
