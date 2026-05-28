/// Ruby: `Domain::Farm::Dtos::FarmListInput`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FarmListInput {
    pub is_admin: bool,
}

impl FarmListInput {
    pub fn new(is_admin: bool) -> Self {
        Self { is_admin }
    }

    pub fn regular_user() -> Self {
        Self::new(false)
    }
}

impl Default for FarmListInput {
    fn default() -> Self {
        Self::regular_user()
    }
}
