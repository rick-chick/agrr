/// Ruby: `Domain::Auth::Dtos::AuthTestMockLoginInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthTestMockLoginInput {
    pub google_id: String,
    pub email: String,
    pub name: String,
    pub avatar_source_url: String,
    pub grant_admin: bool,
    pub stashed_public_plan: bool,
    pub pending_return_to: Option<String>,
    pub pending_return_to_allowed: bool,
}

impl AuthTestMockLoginInput {
    pub fn new(
        google_id: impl Into<String>,
        email: impl Into<String>,
        name: impl Into<String>,
        avatar_source_url: impl Into<String>,
        grant_admin: bool,
        stashed_public_plan: bool,
        pending_return_to: Option<impl Into<String>>,
        pending_return_to_allowed: bool,
    ) -> Self {
        let pending_return_to = pending_return_to.map(|s| s.into().trim().to_string());
        let pending_return_to = pending_return_to.filter(|s| !s.is_empty());

        Self {
            google_id: google_id.into(),
            email: email.into(),
            name: name.into(),
            avatar_source_url: avatar_source_url.into(),
            grant_admin,
            stashed_public_plan,
            pending_return_to,
            pending_return_to_allowed,
        }
    }
}
