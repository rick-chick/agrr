#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserAccountDeleteInput {
    pub user_id: i64,
    pub confirm: bool,
    pub email_confirm: Option<String>,
}
