pub trait TaskScheduleBlueprintEnsureInputPort: Send + Sync {
    fn ensure_for_plan(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
