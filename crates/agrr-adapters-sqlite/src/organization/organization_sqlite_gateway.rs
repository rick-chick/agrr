//! Ruby: `Adapters::Organization::Gateways::OrganizationSqliteGateway`

use crate::pool::SqlitePool;
use agrr_domain::organization::entities::OrganizationEntity;
use agrr_domain::organization::gateways::OrganizationGateway;
use rusqlite::{params, OptionalExtension};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};

pub struct OrganizationSqliteGateway {
    pool: SqlitePool,
}

impl OrganizationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn map_organization_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<OrganizationEntity> {
    let is_personal: i64 = row.get(3)?;
    Ok(OrganizationEntity {
        id: row.get(0)?,
        name: row.get(1)?,
        slug: row.get(2)?,
        is_personal: is_personal != 0,
        created_at: row.get(4)?,
        updated_at: row.get(5)?,
    })
}

fn now_rails_datetime() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".into())
}

impl OrganizationGateway for OrganizationSqliteGateway {
    fn find_by_id(
        &self,
        organization_id: i64,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, slug, is_personal, created_at, updated_at \
                 FROM organizations WHERE id = ?1",
                params![organization_id],
                map_organization_row,
            )
        })
    }

    fn find_by_slug(
        &self,
        slug: &str,
    ) -> Result<Option<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, slug, is_personal, created_at, updated_at \
                 FROM organizations WHERE slug = ?1",
                params![slug],
                map_organization_row,
            )
            .optional()
        })
    }

    fn list_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT o.id, o.name, o.slug, o.is_personal, o.created_at, o.updated_at \
                 FROM organizations o \
                 INNER JOIN organization_memberships m ON m.organization_id = o.id \
                 WHERE m.user_id = ?1 \
                 ORDER BY o.id",
            )?;
            let rows = stmt
                .query_map(params![user_id], map_organization_row)?
                .collect::<Result<Vec<_>, _>>()?;
            Ok(rows)
        })
    }

    fn create(
        &self,
        name: &str,
        slug: &str,
        is_personal: bool,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        let now = now_rails_datetime();
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO organizations (name, slug, is_personal, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![name, slug, is_personal as i64, now, now],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, name, slug, is_personal, created_at, updated_at \
                 FROM organizations WHERE id = ?1",
                params![id],
                map_organization_row,
            )
        })
    }

    fn update(
        &self,
        organization_id: i64,
        name: Option<&str>,
        slug: Option<&str>,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        let existing = self.find_by_id(organization_id)?;
        let new_name = name.unwrap_or(existing.name.as_str());
        let new_slug = slug.unwrap_or(existing.slug.as_str());
        let now = now_rails_datetime();
        self.pool.with_write_box(|conn| {
            let updated = conn.execute(
                "UPDATE organizations SET name = ?1, slug = ?2, updated_at = ?3 WHERE id = ?4",
                params![new_name, new_slug, now, organization_id],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            conn.query_row(
                "SELECT id, name, slug, is_personal, created_at, updated_at \
                 FROM organizations WHERE id = ?1",
                params![organization_id],
                map_organization_row,
            )
        })
    }

    fn delete(
        &self,
        organization_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute_batch("BEGIN IMMEDIATE")?;
            let _ = conn.execute(
                "DELETE FROM organization_memberships WHERE organization_id = ?1",
                params![organization_id],
            )?;
            let deleted = conn.execute(
                "DELETE FROM organizations WHERE id = ?1",
                params![organization_id],
            )?;
            if deleted == 0 {
                let _ = conn.execute_batch("ROLLBACK");
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            conn.execute_batch("COMMIT")?;
            Ok(())
        })
    }
}
