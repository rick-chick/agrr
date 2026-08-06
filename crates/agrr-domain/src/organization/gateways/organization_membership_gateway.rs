use crate::organization::dtos::OrganizationRole;
use crate::organization::entities::OrganizationMembershipEntity;

/// Ruby: `Domain::Organization::Gateways::OrganizationMembershipGateway`
pub trait OrganizationMembershipGateway: Send + Sync {
    fn find_membership(
        &self,
        organization_id: i64,
        user_id: i64,
    ) -> Result<Option<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_for_organization(
        &self,
        organization_id: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        organization_id: i64,
        user_id: i64,
        role: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_role(
        &self,
        membership_id: i64,
        role: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        membership_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
