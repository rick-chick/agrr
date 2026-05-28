/// Domain user principal (Ruby: duck-typed `admin?` / `id` / `anonymous?`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct User {
    pub id: i64,
    pub admin: bool,
    pub anonymous: bool,
}

impl User {
    pub fn new(id: i64, admin: bool) -> Self {
        Self {
            id,
            admin,
            anonymous: false,
        }
    }
}
