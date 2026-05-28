use crate::fertilize::entities::FertilizeEntity;
use crate::shared::attr::AttrMap;

/// Result struct for AI update adapter (Ruby `FertilizeUpdateForAiAdapter::Result`).
#[derive(Debug, Clone)]
pub struct AiUpdateResult {
    pub success: bool,
    pub data: Option<FertilizeEntity>,
    pub error: Option<String>,
}

/// Ruby: AI update adapter port (`call(fertilize_id, attrs) -> result`)
pub trait AiUpdateInteractorPort: Send + Sync {
    fn call(&self, fertilize_id: i64, attrs: AttrMap) -> AiUpdateResult;
}
