#[derive(Debug, Clone, PartialEq)]
pub struct AgriculturalTaskSnapshot {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub is_reference: bool,
}
