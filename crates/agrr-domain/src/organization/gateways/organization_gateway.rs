use crate::organization::entities::OrganizationEntity;

/// Ruby: `Domain::Organization::Gateways::OrganizationGateway`
pub trait OrganizationGateway: Send + Sync {
    fn find_by_id(
        &self,
        organization_id: i64,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_slug(
        &self,
        slug: &str,
    ) -> Result<Option<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        name: &str,
        slug: &str,
        is_personal: bool,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        organization_id: i64,
        name: Option<&str>,
        slug: Option<&str>,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        organization_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
