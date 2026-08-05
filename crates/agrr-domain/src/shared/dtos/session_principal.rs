/// Ruby: `Domain::Shared::Dtos::SessionPrincipal`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionPrincipal {
    pub id: i64,
    pub email: String,
    pub name: String,
    pub admin: bool,
    pub anonymous: bool,
    /// `Some` when resolved via API key; `None` for session cookie (unrestricted Masters access).
    pub api_key_scopes: Option<Vec<String>>,
}

impl SessionPrincipal {
    pub fn admin(&self) -> bool {
        self.admin
    }

    pub fn anonymous(&self) -> bool {
        self.anonymous
    }

    pub fn authenticated(&self) -> bool {
        !self.anonymous
    }
}
