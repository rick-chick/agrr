//! Personal organization backfill and ensure (issue #611).

use crate::pool::SqlitePool;
use agrr_domain::organization::dtos::OrganizationRole;
use agrr_domain::organization::gateways::PersonalOrganizationGateway;
use agrr_domain::organization::gateways::PersonalOrganizationUserRow;
use agrr_domain::organization::policies::{
    personal_organization_name, personal_organization_slug,
};
use rusqlite::{params, OptionalExtension};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};

pub struct PersonalOrganizationSqliteGateway {
    pool: SqlitePool,
}

impl PersonalOrganizationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn now_rails_datetime() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".into())
}

const TIER1_TABLES: &[&str] = &[
    "farms",
    "crops",
    "cultivation_plans",
    "fields",
    "agricultural_tasks",
    "fertilizes",
    "interaction_rules",
    "pests",
    "pesticides",
];

impl PersonalOrganizationGateway for PersonalOrganizationSqliteGateway {
    fn ensure_personal_organization(
        &self,
        user_id: i64,
        email: &str,
        _name: &str,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let now = now_rails_datetime();
        self.pool.with_write_box(|conn| {
            let existing_org_id: Option<i64> = conn
                .query_row(
                    "SELECT o.id FROM organizations o \
                     INNER JOIN organization_memberships m ON m.organization_id = o.id \
                     WHERE m.user_id = ?1 AND o.is_personal = 1 \
                     LIMIT 1",
                    params![user_id],
                    |row| row.get(0),
                )
                .optional()?;

            let organization_id = if let Some(id) = existing_org_id {
                id
            } else {
                let slug = personal_organization_slug(user_id);
                let org_name = personal_organization_name(email);
                conn.execute(
                    "INSERT INTO organizations (name, slug, is_personal, created_at, updated_at) \
                     VALUES (?1, ?2, 1, ?3, ?4)",
                    params![org_name, slug, now, now],
                )?;
                let id = conn.last_insert_rowid();
                conn.execute(
                    "INSERT INTO organization_memberships \
                     (organization_id, user_id, role, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5)",
                    params![id, user_id, OrganizationRole::Owner.as_str(), now, now],
                )?;
                id
            };

            backfill_tier1_organization_ids(conn, user_id, organization_id)?;
            Ok(organization_id)
        })
    }

    fn list_users_needing_personal_organization(
        &self,
    ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT u.id, COALESCE(u.email, ''), COALESCE(u.name, '') \
                 FROM users u \
                 WHERE NOT EXISTS ( \
                   SELECT 1 FROM organization_memberships m \
                   INNER JOIN organizations o ON o.id = m.organization_id \
                   WHERE m.user_id = u.id AND o.is_personal = 1 \
                 ) \
                 ORDER BY u.id",
            )?;
            let rows = stmt
                .query_map([], |row| {
                    Ok(PersonalOrganizationUserRow {
                        user_id: row.get(0)?,
                        email: row.get(1)?,
                        name: row.get(2)?,
                    })
                })?
                .collect::<Result<Vec<_>, _>>()?;
            Ok(rows)
        })
    }
}

fn backfill_tier1_organization_ids(
    conn: &rusqlite::Connection,
    user_id: i64,
    organization_id: i64,
) -> rusqlite::Result<()> {
    for table in TIER1_TABLES {
        conn.execute(
            &format!(
                "UPDATE {table} SET organization_id = ?1 \
                 WHERE user_id = ?2 AND organization_id IS NULL"
            ),
            params![organization_id, user_id],
        )?;
    }
    conn.execute(
        "UPDATE fields SET organization_id = ?1 \
         WHERE organization_id IS NULL AND farm_id IN ( \
           SELECT id FROM farms WHERE user_id = ?2 AND organization_id = ?1 \
         )",
        params![organization_id, user_id],
    )?;
    Ok(())
}
