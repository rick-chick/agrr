//! Ruby: `FieldActiveRecordGateway` — `get_total_area_by_farm_id` for plan init.

use crate::pool::SqlitePool;
use agrr_domain::field::gateways::FieldGateway;
use rusqlite::params;

pub struct FieldSqliteGateway {
    pool: SqlitePool,
}

impl FieldSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn unsupported(method: &str) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        format!("{method} not supported in P6 field read slice"),
    ))
}

impl FieldGateway for FieldSqliteGateway {
    fn get_total_area_by_farm_id(
        &self,
        farm_id: i64,
    ) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let total: f64 = conn.query_row(
                "SELECT COALESCE(SUM(area), 0) FROM fields WHERE farm_id = ?1",
                params![farm_id],
                |row| row.get(0),
            )?;
            Ok(total)
        })
    }

    fn farm_fields_list(
        &self,
        _farm_id: i64,
    ) -> Result<agrr_domain::field::results::FarmFieldsList, Box<dyn std::error::Error + Send + Sync>>
    {
        Err(unsupported("farm_fields_list"))
    }

    fn field_with_farm(
        &self,
        _field_id: i64,
    ) -> Result<agrr_domain::field::results::FieldWithFarm, Box<dyn std::error::Error + Send + Sync>>
    {
        Err(unsupported("field_with_farm"))
    }

    fn create(
        &self,
        _create_input: &agrr_domain::field::dtos::FieldCreateInput,
        _farm_id: i64,
        _farm_access_filter: &agrr_domain::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
            agrr_domain::shared::policies::farm_policy::FarmRecordAccessPolicy,
        >,
    ) -> Result<agrr_domain::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        Err(unsupported("create"))
    }

    fn update(
        &self,
        _field_id: i64,
        _update_input: &agrr_domain::field::dtos::FieldUpdateInput,
    ) -> Result<agrr_domain::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        Err(unsupported("update"))
    }

    fn delete(
        &self,
        _field_id: i64,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        Err(unsupported("delete"))
    }
}
