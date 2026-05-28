use crate::pest::dtos::HttpStatus;

/// Ruby: `Domain::Pest::Dtos::PestAiCreateOutput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PestAiCreateOutput {
    pub http_status: HttpStatus,
    pub pest_id: i64,
    pub pest_name: String,
    pub name_scientific: Option<String>,
    pub family: Option<String>,
    pub order: Option<String>,
    pub description: Option<String>,
    pub occurrence_season: Option<String>,
    pub message: String,
}
