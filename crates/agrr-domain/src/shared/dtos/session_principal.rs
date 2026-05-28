/// Ruby: `Domain::Shared::Dtos::SessionPrincipal`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionPrincipal {
    pub id: i64,
    pub email: String,
    pub name: String,
    pub admin: bool,
    pub anonymous: bool,
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
