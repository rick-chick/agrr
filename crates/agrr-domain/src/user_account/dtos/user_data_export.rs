use serde::{Deserialize, Serialize};

use super::UserExportSnapshot;

/// Full personal data export payload (JSON-serializable).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UserDataExport {
    pub exported_at: String,
    pub user: UserExportSnapshot,
    pub farms: Vec<serde_json::Value>,
    pub crops: Vec<serde_json::Value>,
    pub cultivation_plans: Vec<serde_json::Value>,
}
