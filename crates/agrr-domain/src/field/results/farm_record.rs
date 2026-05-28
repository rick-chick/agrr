use crate::shared::record_ref::RecordRef;

/// Minimal farm surface for field bounded context (full `FarmEntity` lives in `farm` context).
#[derive(Debug, Clone, PartialEq)]
pub struct FarmRecord {
    pub id: i64,
    pub name: String,
    pub user_id: Option<i64>,
    pub is_reference: bool,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub region: Option<String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl RecordRef for FarmRecord {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}
