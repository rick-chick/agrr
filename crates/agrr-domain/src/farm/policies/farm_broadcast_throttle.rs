/// Ruby: `Domain::Farm::Policies::FarmBroadcastThrottlePolicy`
pub struct FarmBroadcastThrottlePolicy;

impl FarmBroadcastThrottlePolicy {
    pub fn should_update_broadcast_time(
        last_broadcast_at: Option<f64>,
        current_time: f64,
        throttle_seconds: f64,
    ) -> bool {
        last_broadcast_at
            .map(|last| (current_time - last) >= throttle_seconds)
            .unwrap_or(true)
    }
}
