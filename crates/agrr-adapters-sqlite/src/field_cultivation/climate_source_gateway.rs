//! Ruby: `Adapters::FieldCultivation::Gateways::FieldCultivationClimateSourceActiveRecordGateway`
//!
//! Rows are mapped into `agrr-domain` DTOs only; business rules stay in domain mappers/policies.

use agrr_domain::field_cultivation::dtos::{
    FieldCultivationApiSummary, FieldCultivationApiUpdateOutput,
    FieldCultivationClimateSourceSnapshot, FieldCultivationPlanAccessSnapshot,
    WeatherPredictionTargets,
};
use agrr_domain::field_cultivation::gateways::{
    FieldCultivationClimateSourceGateway, FieldCultivationGateway,
};
use rusqlite::Connection;

/// SQLite-backed climate / API read gateway (narrow I/O).
pub struct FieldCultivationClimateSourceSqliteGateway {
    database_path: String,
}

impl FieldCultivationClimateSourceSqliteGateway {
    pub fn new(database_path: impl Into<String>) -> Self {
        Self {
            database_path: database_path.into(),
        }
    }

    fn open_connection(&self) -> Result<Connection, rusqlite::Error> {
        Connection::open(&self.database_path)
    }
}

impl FieldCultivationClimateSourceGateway for FieldCultivationClimateSourceSqliteGateway {
    fn find_plan_access_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let conn = self.open_connection()?;
        let row = load_field_cultivation_row(&conn, field_cultivation_id)?;
        Ok(row.plan_access_snapshot())
    }

    fn find_climate_source_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationClimateSourceSnapshot, Box<dyn std::error::Error + Send + Sync>>
    {
        let conn = self.open_connection()?;
        let row = load_field_cultivation_row(&conn, field_cultivation_id)?;
        Ok(row.climate_source_snapshot())
    }

    fn find_weather_prediction_targets_by_plan_id(
        &self,
        _plan_id: i64,
    ) -> Result<WeatherPredictionTargets, Box<dyn std::error::Error + Send + Sync>> {
        Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            "find_weather_prediction_targets_by_plan_id: implement per BC cutover PR",
        )))
    }
}

impl FieldCultivationGateway for FieldCultivationClimateSourceSqliteGateway {
    fn find_plan_access_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        FieldCultivationClimateSourceGateway::find_plan_access_snapshot_by_field_cultivation_id(
            self,
            field_cultivation_id,
        )
    }

    fn find_api_summary_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationApiSummary, Box<dyn std::error::Error + Send + Sync>> {
        let conn = self.open_connection()?;
        let row = load_field_cultivation_row(&conn, field_cultivation_id)?;
        Ok(row.api_summary()?)
    }

    fn update_field_cultivation_schedule(
        &self,
        _field_cultivation_id: i64,
        _start_date: &str,
        _completion_date: &str,
        _cultivation_days: Option<i32>,
    ) -> Result<FieldCultivationApiUpdateOutput, Box<dyn std::error::Error + Send + Sync>> {
        Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            "update_field_cultivation_schedule: single-writer cutover only",
        )))
    }
}

struct FieldCultivationClimateRow {
    fc_id: i64,
    plan_type_public: bool,
    plan_type_private: bool,
    plan_user_id: Option<i64>,
    field_name: String,
    crop_name: String,
    start_date: Option<time::Date>,
    completion_date: Option<time::Date>,
    farm_id: i64,
    farm_name: String,
    farm_latitude: f64,
    farm_longitude: f64,
    weather_location_id: Option<i64>,
    weather_location_timezone: Option<String>,
    plan_id: i64,
    prediction_target_end_date: Option<time::Date>,
    calculated_planning_end_date: Option<time::Date>,
    predicted_weather_data: Option<serde_json::Value>,
    plan_crop_crop_id: Option<i64>,
    area: f64,
    cultivation_days: Option<i32>,
    estimated_cost: Option<f64>,
    gdd: Option<f64>,
    status: String,
}

impl FieldCultivationClimateRow {
    fn plan_access_snapshot(&self) -> FieldCultivationPlanAccessSnapshot {
        FieldCultivationPlanAccessSnapshot::new(
            self.fc_id,
            self.plan_type_public,
            self.plan_type_private,
            self.plan_user_id,
        )
    }

    fn climate_source_snapshot(&self) -> FieldCultivationClimateSourceSnapshot {
        FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: self.fc_id,
            field_name: self.field_name.clone(),
            crop_name: self.crop_name.clone(),
            start_date: self.start_date,
            completion_date: self.completion_date,
            farm_id: self.farm_id,
            farm_name: self.farm_name.clone(),
            farm_latitude: self.farm_latitude,
            farm_longitude: self.farm_longitude,
            weather_location_id: self.weather_location_id,
            weather_location_timezone: self.weather_location_timezone.clone(),
            plan_id: self.plan_id,
            plan_type_public: self.plan_type_public,
            prediction_target_end_date: self.prediction_target_end_date,
            calculated_planning_end_date: self.calculated_planning_end_date,
            predicted_weather_data: self.predicted_weather_data.clone(),
            plan_crop_crop_id: self.plan_crop_crop_id,
        }
    }

    fn api_summary(&self) -> Result<FieldCultivationApiSummary, rusqlite::Error> {
        let start_date = self
            .start_date
            .ok_or(rusqlite::Error::InvalidParameterName("start_date".into()))?;
        let completion_date = self
            .completion_date
            .ok_or(rusqlite::Error::InvalidParameterName(
                "completion_date".into(),
            ))?;
        Ok(FieldCultivationApiSummary {
            id: self.fc_id,
            field_name: self.field_name.clone(),
            crop_name: self.crop_name.clone(),
            area: self.area,
            start_date,
            completion_date,
            cultivation_days: self.cultivation_days.unwrap_or(0),
            estimated_cost: self.estimated_cost.unwrap_or(0.0),
            gdd: self.gdd,
            status: self.status.clone(),
        })
    }
}

fn load_field_cultivation_row(
    conn: &Connection,
    field_cultivation_id: i64,
) -> Result<FieldCultivationClimateRow, rusqlite::Error> {
    let sql = r#"
        SELECT
          fc.id AS fc_id,
          cp.plan_type AS plan_type,
          cp.user_id AS plan_user_id,
          cpf.name AS field_name,
          cpc.name AS crop_name,
          cpc.variety AS crop_variety,
          fc.start_date,
          fc.completion_date,
          f.id AS farm_id,
          f.name AS farm_name,
          f.latitude,
          f.longitude,
          wl.id AS weather_location_id,
          wl.timezone AS weather_location_timezone,
          cp.id AS plan_id,
          cp.prediction_target_end_date,
          cp.calculated_planning_end_date,
          cp.predicted_weather_data,
          cpc.crop_id AS plan_crop_crop_id,
          fc.area,
          fc.cultivation_days,
          fc.estimated_cost,
          fc.optimization_result,
          fc.status
        FROM field_cultivations fc
        INNER JOIN cultivation_plans cp ON cp.id = fc.cultivation_plan_id
        INNER JOIN farms f ON f.id = cp.farm_id
        LEFT JOIN weather_locations wl ON wl.id = f.weather_location_id
        INNER JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id
        LEFT JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id
        WHERE fc.id = ?1
    "#;

    let mut stmt = conn.prepare(sql)?;
    let mut rows = stmt.query([field_cultivation_id])?;
    let row = rows.next()?.ok_or(rusqlite::Error::QueryReturnedNoRows)?;

    let plan_type: String = row.get("plan_type")?;
    let plan_type_public = plan_type == "public";
    let plan_type_private = plan_type == "private";

    let crop_name = crop_display_name(
        row.get::<_, String>("crop_name")?,
        row.get::<_, Option<String>>("crop_variety")?,
    );

    let optimization_result: Option<String> = row.get("optimization_result")?;
    let gdd = optimization_result
        .as_deref()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(s).ok())
        .and_then(|v| v.get("raw")?.get("total_gdd")?.as_f64());

    Ok(FieldCultivationClimateRow {
        fc_id: row.get("fc_id")?,
        plan_type_public,
        plan_type_private,
        plan_user_id: row.get("plan_user_id")?,
        field_name: row.get("field_name")?,
        crop_name,
        start_date: parse_optional_date(row.get::<_, Option<String>>("start_date")?),
        completion_date: parse_optional_date(row.get::<_, Option<String>>("completion_date")?),
        farm_id: row.get("farm_id")?,
        farm_name: row.get("farm_name")?,
        farm_latitude: row.get("latitude")?,
        farm_longitude: row.get("longitude")?,
        weather_location_id: row.get("weather_location_id")?,
        weather_location_timezone: row.get("weather_location_timezone")?,
        plan_id: row.get("plan_id")?,
        prediction_target_end_date: parse_optional_date(
            row.get::<_, Option<String>>("prediction_target_end_date")?,
        ),
        calculated_planning_end_date: parse_optional_date(
            row.get::<_, Option<String>>("calculated_planning_end_date")?,
        ),
        predicted_weather_data: row
            .get::<_, Option<String>>("predicted_weather_data")?
            .and_then(|s| serde_json::from_str(&s).ok()),
        plan_crop_crop_id: row.get("plan_crop_crop_id")?,
        area: row.get("area")?,
        cultivation_days: row.get("cultivation_days")?,
        estimated_cost: row.get("estimated_cost")?,
        gdd,
        status: row.get("status")?,
    })
}

fn crop_display_name(name: String, variety: Option<String>) -> String {
    if let Some(variety) = variety.filter(|v| !v.is_empty()) {
        format!("{name}（{variety}）")
    } else {
        name
    }
}

fn parse_optional_date(raw: Option<String>) -> Option<time::Date> {
    raw.and_then(|s| {
        let format = time::format_description::parse("[year]-[month]-[day]").ok()?;
        time::Date::parse(&s, &format).ok()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_db_uri(name: &str) -> String {
        format!("file:{name}?mode=memory&cache=shared")
    }

    fn in_memory_schema(conn: &Connection) {
        conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS farms (id INTEGER PRIMARY KEY, name TEXT, latitude REAL, longitude REAL, weather_location_id INTEGER);
            CREATE TABLE IF NOT EXISTS weather_locations (id INTEGER PRIMARY KEY, timezone TEXT);
            CREATE TABLE IF NOT EXISTS cultivation_plans (
              id INTEGER PRIMARY KEY, plan_type TEXT, user_id INTEGER,
              farm_id INTEGER, prediction_target_end_date TEXT,
              calculated_planning_end_date TEXT, predicted_weather_data TEXT
            );
            CREATE TABLE IF NOT EXISTS cultivation_plan_crops (
              id INTEGER PRIMARY KEY, crop_id INTEGER, name TEXT NOT NULL, variety TEXT
            );
            CREATE TABLE IF NOT EXISTS cultivation_plan_fields (
              id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, name TEXT NOT NULL, area REAL
            );
            CREATE TABLE IF NOT EXISTS field_cultivations (
              id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER NOT NULL,
              cultivation_plan_field_id INTEGER NOT NULL, cultivation_plan_crop_id INTEGER,
              start_date TEXT, completion_date TEXT,
              area REAL, cultivation_days INTEGER, estimated_cost REAL, optimization_result TEXT, status TEXT
            );
        "#,
        )
        .unwrap();
    }

    fn seed(conn: &Connection) {
        conn.execute("DELETE FROM field_cultivations", []).ok();
        conn.execute("DELETE FROM cultivation_plan_crops", []).ok();
        conn.execute("DELETE FROM cultivation_plans", []).ok();
        conn.execute("DELETE FROM farms", []).ok();
        conn.execute("DELETE FROM weather_locations", []).ok();
        conn.execute(
            "INSERT INTO weather_locations (id, timezone) VALUES (1, 'Asia/Tokyo')",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO farms (id, name, latitude, longitude, weather_location_id) VALUES (1, 'Farm', 35.0, 139.0, 1)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO cultivation_plans (id, plan_type, user_id, farm_id, prediction_target_end_date, calculated_planning_end_date, predicted_weather_data)
             VALUES (1, 'private', 10, 1, '2026-12-31', '2026-12-31', NULL)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name, area) VALUES (1, 1, 'North', 10.0)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, crop_id, name, variety) VALUES (1, 5, 'Tomato', NULL)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO field_cultivations (id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, start_date, completion_date, area, cultivation_days, estimated_cost, optimization_result, status)
             VALUES (42, 1, 1, 1, '2026-01-01', '2026-06-01', 10.0, 150, 1.0, '{\"raw\":{\"total_gdd\":99.5}}', 'completed')",
            [],
        )
        .unwrap();
    }

    #[test]
    fn loads_narrow_snapshots_from_sqlite() {
        let db = test_db_uri("fc_climate_gateway_load");
        let conn = Connection::open(&db).unwrap();
        in_memory_schema(&conn);
        seed(&conn);

        let gateway = FieldCultivationClimateSourceSqliteGateway::new(&db);
        let plan_access =
            FieldCultivationClimateSourceGateway::find_plan_access_snapshot_by_field_cultivation_id(
                &gateway, 42,
            )
            .expect("plan access");
        let climate_source =
            FieldCultivationClimateSourceGateway::find_climate_source_snapshot_by_field_cultivation_id(
                &gateway, 42,
            )
            .expect("climate source");
        let api_summary =
            FieldCultivationGateway::find_api_summary_by_field_cultivation_id(&gateway, 42)
                .expect("api summary");

        assert_eq!(plan_access.field_cultivation_id, 42);
        assert!(!plan_access.plan_type_public());
        assert_eq!(climate_source.farm_id, 1);
        assert_eq!(api_summary.gdd, Some(99.5));
    }

    #[test]
    fn missing_row_returns_error() {
        let db = test_db_uri("fc_climate_gateway_missing");
        let conn = Connection::open(&db).unwrap();
        in_memory_schema(&conn);

        let gateway = FieldCultivationClimateSourceSqliteGateway::new(&db);
        assert!(
            FieldCultivationClimateSourceGateway::find_plan_access_snapshot_by_field_cultivation_id(
                &gateway, 999
            )
            .is_err()
        );
    }
}
