/// Canonical crop cultivation method stored on `crops.cultivation_method`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CropCultivationMethod {
    DirectSow,
    Transplant,
}

impl CropCultivationMethod {
    pub fn parse_db_str(raw: &str) -> Option<Self> {
        match raw {
            "direct_sow" => Some(Self::DirectSow),
            "transplant" => Some(Self::Transplant),
            _ => None,
        }
    }

    pub fn is_transplant(self) -> bool {
        matches!(self, Self::Transplant)
    }
}
