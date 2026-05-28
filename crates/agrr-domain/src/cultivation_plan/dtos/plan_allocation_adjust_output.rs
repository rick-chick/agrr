//! Ruby DTO stub for gateway/interactor porting

#[derive(Debug, Clone, PartialEq)]
pub struct PlanAllocationAdjustOutput {
    pub message: String,
    pub skipped: bool,
    pub payload: Option<serde_json::Value>,
}
