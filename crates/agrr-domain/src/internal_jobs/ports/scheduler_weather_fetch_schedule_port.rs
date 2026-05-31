use time::Date;

/// Schedules in-process `FetchWeatherDataJob` equivalents with staggered delays.
pub trait SchedulerWeatherFetchSchedulePort: Send + Sync {
    fn schedule_fetch(
        &self,
        farm_id: i64,
        latitude: f64,
        longitude: f64,
        start_date: Date,
        end_date: Date,
        delay_secs: u64,
    );

    /// Flush queued steps to the job dispatcher (no-op if nothing scheduled).
    fn flush(&self);
}
