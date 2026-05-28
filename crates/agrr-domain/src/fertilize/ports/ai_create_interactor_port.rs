use crate::fertilize::entities::FertilizeEntity;
use crate::shared::attr::AttrMap;

/// Result struct for AI create adapter (Ruby `FertilizeCreateForAiAdapter::Result`).
#[derive(Debug, Clone)]
pub struct AiCreateResult {
    pub success: bool,
    pub data: Option<FertilizeEntity>,
    pub error: Option<String>,
}

/// Ruby: AI create adapter port (`call(attrs) -> result`)
pub trait AiCreateInteractorPort: Send + Sync {
    fn call(&self, attrs: AttrMap) -> AiCreateResult;
}
