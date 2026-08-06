#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationCreateInput {
    pub name: String,
    pub slug: String,
}
