/// Ruby: `Domain::Pest::Dtos::PestCropAssociationSyncResult`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PestCropAssociationSyncResult {
    pub added: i64,
    pub removed: i64,
}

impl PestCropAssociationSyncResult {
    pub fn new(added: i64, removed: i64) -> Self {
        Self { added, removed }
    }
}
