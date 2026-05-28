use rust_decimal::Decimal;

#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskTemplatePersistAttributes {
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub weather_dependency: Option<String>,
    pub required_tools: Vec<String>,
    pub skill_level: Option<String>,
}
