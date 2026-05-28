use serde_json::Value;

/// Ruby: `Domain::Shared::Ports::FarmRefreshBroadcastPort`
pub trait FarmRefreshBroadcastPort: Send + Sync {
    fn broadcast_farm_weather_progress(&self, farm_id: i64, payload: &Value);
}
