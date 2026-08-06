//! Ruby: `Adapters::Organization::Gateways::OrganizationMembershipSqliteGateway`

use crate::pool::SqlitePool;
use agrr_domain::organization::dtos::OrganizationRole;
use agrr_domain::organization::entities::OrganizationMembershipEntity;
use agrr_domain::organization::gateways::OrganizationMembershipGateway;
use rusqlite::{params, OptionalExtension};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};

pub struct OrganizationMembershipSqliteGateway {
    pool: SqlitePool,
}

impl OrganizationMembershipSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn map_membership_row(
    row: &rusqlite::Row<'_>,
) -> Result<OrganizationMembershipEntity, rusqlite::Error> {
    let role_str: String = row.get(3)?;
    let role = OrganizationRole::parse(&role_str).ok_or_else(|| {
        rusqlite::Error::FromSqlConversionFailure(
            3,
            rusqlite::types::Type::Text,
            Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "invalid role",
            )),
        )
    })?;
    Ok(OrganizationMembershipEntity {
        id: row.get(0)?,
        organization_id: row.get(1)?,
        user_id: row.get(2)?,
        role,
        created_at: row.get(4)?,
        updated_at: row.get(5)?,
    })
}

fn now_rails_datetime() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".into())
}

impl OrganizationMembershipGateway for OrganizationMembershipSqliteGateway {
    fn find_membership(
        &self,
        organization_id: i64,
        user_id: i64,
    ) -> Result<Option<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, organization_id, user_id, role, created_at, updated_at \
                 FROM organization_memberships \
                 WHERE organization_id = ?1 AND user_id = ?2",
                params![organization_id, user_id],
                map_membership_row,
            )
            .optional()
        })
    }

    fn list_for_organization(
        &self,
        organization_id: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, organization_id, user_id, role, created_at, updated_at \
                 FROM organization_memberships WHERE organization_id = ?1 ORDER BY id",
            )?;
            let rows = stmt
                .query_map(params![organization_id], map_membership_row)?
                .collect::<Result<Vec<_>, _>>()?;
            Ok(rows)
        })
    }

    fn list_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, organization_id, user_id, role, created_at, updated_at \
                 FROM organization_memberships WHERE user_id = ?1 ORDER BY id",
            )?;
            let rows = stmt
                .query_map(params![user_id], map_membership_row)?
                .collect::<Result<Vec<_>, _>>()?;
            Ok(rows)
        })
    }

    fn create(
        &self,
        organization_id: i64,
        user_id: i64,
        role: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>> {
        let now = now_rails_datetime();
        let role_str = role.as_str();
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO organization_memberships \
                 (organization_id, user_id, role, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![organization_id, user_id, role_str, now, now],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, organization_id, user_id, role, created_at, updated_at \
                 FROM organization_memberships WHERE id = ?1",
                params![id],
                map_membership_row,
            )
        })
    }

    fn update_role(
        &self,
        membership_id: i64,
        role: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>> {
        let now = now_rails_datetime();
        self.pool.with_write_box(|conn| {
            let updated = conn.execute(
                "UPDATE organization_memberships SET role = ?1, updated_at = ?2 WHERE id = ?3",
                params![role.as_str(), now, membership_id],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            conn.query_row(
                "SELECT id, organization_id, user_id, role, created_at, updated_at \
                 FROM organization_memberships WHERE id = ?1",
                params![membership_id],
                map_membership_row,
            )
        })
    }

    fn delete(
        &self,
        membership_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let deleted = conn.execute(
                "DELETE FROM organization_memberships WHERE id = ?1",
                params![membership_id],
            )?;
            if deleted == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(())
        })
    }
}
