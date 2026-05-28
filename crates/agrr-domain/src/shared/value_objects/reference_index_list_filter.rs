//! Ruby: `Domain::Shared::ValueObjects::ReferenceIndexListFilter`

use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReferenceIndexListMode {
    ReferenceOrOwned,
    OwnedNonReference,
}

impl ReferenceIndexListMode {
    pub fn from_str(mode: &str) -> Option<Self> {
        match mode {
            "reference_or_owned" => Some(Self::ReferenceOrOwned),
            "owned_non_reference" => Some(Self::OwnedNonReference),
            _ => None,
        }
    }
}

/// List scope for reference master indexes (Interactor / Policy → Gateway).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReferenceIndexListFilter {
    pub mode: ReferenceIndexListMode,
    pub user_id: i64,
}

impl ReferenceIndexListFilter {
    pub fn new(mode: ReferenceIndexListMode, user_id: i64) -> Self {
        Self { mode, user_id }
    }

    pub fn try_new(mode: &str, user_id: i64) -> Result<Self, InvalidReferenceIndexListMode> {
        let mode = ReferenceIndexListMode::from_str(mode)
            .ok_or(InvalidReferenceIndexListMode(mode.to_string()))?;
        Ok(Self::new(mode, user_id))
    }
}

impl Hash for ReferenceIndexListFilter {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.mode.hash(state);
        self.user_id.hash(state);
    }
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("invalid mode: {0}")]
pub struct InvalidReferenceIndexListMode(pub String);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn equality_and_hash() {
        use std::hash::{Hash, Hasher};
        let a = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 1);
        let b = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 1);
        assert_eq!(a, b);
        let mut ha = std::collections::hash_map::DefaultHasher::new();
        let mut hb = std::collections::hash_map::DefaultHasher::new();
        a.hash(&mut ha);
        b.hash(&mut hb);
        assert_eq!(ha.finish(), hb.finish());
    }

    #[test]
    fn rejects_invalid_mode() {
        assert!(ReferenceIndexListFilter::try_new("bogus", 1).is_err());
    }
}
