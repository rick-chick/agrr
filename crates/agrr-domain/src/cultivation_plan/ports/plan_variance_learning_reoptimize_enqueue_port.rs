//! Enqueue private plan optimization job chain after variance learning apply.

pub trait PlanVarianceLearningReoptimizeEnqueuePort: Send + Sync {
    fn enqueue(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
