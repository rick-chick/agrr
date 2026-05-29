//! Ruby: `Adapters::ContactMessages::Gateways::ContactMessageActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::contact_messages::dtos::CreateContactMessageInput;
use agrr_domain::contact_messages::entities::ContactMessage;
use agrr_domain::contact_messages::gateways::ContactMessageGateway;
use agrr_domain::shared::exceptions::RecordInvalidError;
use rusqlite::params;

pub struct ContactMessageSqliteGateway {
    pool: SqlitePool,
}

impl ContactMessageSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl ContactMessageGateway for ContactMessageSqliteGateway {
    fn find_by_id(&self, id: i64) -> Option<ContactMessage> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, name, email, subject, message, status, source, created_at, sent_at \
                     FROM contact_messages WHERE id = ?1",
                    params![id],
                    |row| {
                        Ok(ContactMessage::new(
                            agrr_domain::contact_messages::entities::ContactMessageAttrs {
                                id: Some(row.get(0)?),
                                name: row.get(1)?,
                                email: row.get(2)?,
                                subject: row.get(3)?,
                                message: row.get(4)?,
                                status: row.get(5)?,
                                source: row.get(6)?,
                                created_at: row.get::<_, Option<String>>(7)?.and_then(|s| {
                                    time::OffsetDateTime::parse(
                                        &s,
                                        &time::format_description::well_known::Iso8601::DEFAULT,
                                    )
                                    .ok()
                                }),
                                sent_at: row.get::<_, Option<String>>(8)?.and_then(|s| {
                                    time::OffsetDateTime::parse(
                                        &s,
                                        &time::format_description::well_known::Iso8601::DEFAULT,
                                    )
                                    .ok()
                                }),
                            },
                        ))
                    },
                )
            })
            .ok()
    }

    fn create(
        &self,
        input: &CreateContactMessageInput,
    ) -> Result<ContactMessage, Box<dyn std::error::Error + Send + Sync>> {
        if input.email.is_empty() || input.message.is_empty() {
            return Err(Box::new(RecordInvalidError::new(
                Some("email and message are required".into()),
                None,
            )));
        }
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO contact_messages (name, email, subject, message, source, status, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, 'queued', datetime('now'), datetime('now'))",
                params![
                    input.name,
                    input.email,
                    input.subject,
                    input.message,
                    input.source,
                ],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, name, email, subject, message, status, source, created_at, sent_at \
                 FROM contact_messages WHERE id = ?1",
                params![id],
                |row| {
                    Ok(ContactMessage::new(
                        agrr_domain::contact_messages::entities::ContactMessageAttrs {
                            id: Some(row.get(0)?),
                            name: row.get(1)?,
                            email: row.get(2)?,
                            subject: row.get(3)?,
                            message: row.get(4)?,
                            status: row.get(5)?,
                            source: row.get(6)?,
                            created_at: row.get::<_, Option<String>>(7)?.and_then(|s| {
                                time::OffsetDateTime::parse(
                                    &s,
                                    &time::format_description::well_known::Iso8601::DEFAULT,
                                )
                                .ok()
                            }),
                            sent_at: row.get::<_, Option<String>>(8)?.and_then(|s| {
                                time::OffsetDateTime::parse(
                                    &s,
                                    &time::format_description::well_known::Iso8601::DEFAULT,
                                )
                                .ok()
                            }),
                        },
                    ))
                },
            )
        })
    }
}
