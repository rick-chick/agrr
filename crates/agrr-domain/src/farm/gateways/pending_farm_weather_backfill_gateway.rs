//! Narrow read for farms stuck at `pending` before initial weather fetch.

/// Lists user-owned farms that have coordinates but never started weather fetch.
pub trait PendingFarmWeatherBackfillGateway: Send + Sync {
    /// `is_reference = 0`, coordinates set, `weather_data_status` pending (or null).
    fn list_user_farm_ids_pending_initial_weather_fetch(
        &self,
    ) -> Result<Vec<i64>, String>;
}
