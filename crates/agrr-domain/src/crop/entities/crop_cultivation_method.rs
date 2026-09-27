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

#[cfg(test)]
mod crop_cultivation_method_test {
    use super::CropCultivationMethod;

    #[test]
    fn parse_db_str_recognizes_canonical_values() {
        assert_eq!(
            CropCultivationMethod::parse_db_str("direct_sow"),
            Some(CropCultivationMethod::DirectSow)
        );
        assert_eq!(
            CropCultivationMethod::parse_db_str("transplant"),
            Some(CropCultivationMethod::Transplant)
        );
    }

    #[test]
    fn parse_db_str_returns_none_for_unknown_or_legacy_values() {
        assert_eq!(CropCultivationMethod::parse_db_str("unknown"), None);
        assert_eq!(CropCultivationMethod::parse_db_str(""), None);
        assert_eq!(CropCultivationMethod::parse_db_str("DirectSow"), None);
    }

    #[test]
    fn is_transplant_is_true_only_for_transplant() {
        assert!(!CropCultivationMethod::DirectSow.is_transplant());
        assert!(CropCultivationMethod::Transplant.is_transplant());
    }
}
