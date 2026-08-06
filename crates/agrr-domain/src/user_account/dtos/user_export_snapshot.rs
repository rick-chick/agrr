use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UserExportSnapshot {
    pub id: i64,
    pub email: Option<String>,
    pub name: Option<String>,
    pub created_at: Option<String>,
}
