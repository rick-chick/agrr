//! Enqueue immediate task schedule regeneration without orchestration details in domain.

pub trait TaskScheduleRegenEnqueuePort: Send + Sync {
    fn enqueue_immediate(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
