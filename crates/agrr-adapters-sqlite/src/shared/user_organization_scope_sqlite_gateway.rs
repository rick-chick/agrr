//! Resolves organization IDs a user may access via membership.

use crate::organization::OrganizationMembershipSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::shared::gateways::UserOrganizationScopeGateway;

pub struct UserOrganizationScopeSqliteGateway {
    membership_gateway: OrganizationMembershipSqliteGateway,
}

impl UserOrganizationScopeSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            membership_gateway: OrganizationMembershipSqliteGateway::new(pool),
        }
    }
}

impl UserOrganizationScopeGateway for UserOrganizationScopeSqliteGateway {
    fn organization_ids_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        use agrr_domain::organization::gateways::OrganizationMembershipGateway;
        let memberships = self.membership_gateway.list_for_user(user_id)?;
        Ok(memberships
            .into_iter()
            .map(|m| m.organization_id)
            .collect())
    }
}
