/// Ruby: fertilize AI query gateway (agrr CLI)
pub trait FertilizeAiQueryGateway: Send + Sync {
    fn fetch_for_create(
        &self,
        name: &str,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>>;

    fn fetch_for_update(
        &self,
        id: i64,
        name: &str,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>>;
}
