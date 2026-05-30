use crate::pest::entities::PestEntity;
use crate::shared::attr::AttrMap;

#[derive(Debug, Clone)]
pub struct PestAiCreateResult {
    pub success: bool,
    pub data: Option<PestEntity>,
    pub error: Option<String>,
}

/// Ruby: `Adapters::Pest::PestCreateForAiAdapter`
pub trait PestAiCreateInteractorPort: Send + Sync {
    fn call(&self, attrs: AttrMap) -> PestAiCreateResult;
}
