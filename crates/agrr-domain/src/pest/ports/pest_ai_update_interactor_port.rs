use crate::pest::entities::PestEntity;
use crate::shared::attr::AttrMap;

#[derive(Debug, Clone)]
pub struct PestAiUpdateResult {
    pub success: bool,
    pub data: Option<PestEntity>,
    pub error: Option<String>,
}

/// Ruby: AI update adapter port for pest AI update interactor.
pub trait PestAiUpdateInteractorPort: Send + Sync {
    fn call(&self, pest_id: i64, attrs: AttrMap) -> PestAiUpdateResult;
}
