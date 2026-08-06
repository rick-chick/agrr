#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationUpdateInput {
    pub name: Option<String>,
    pub slug: Option<String>,
}
