//! Ruby: `Adapters::Crop::CropAiUpsertActiveRecordPersistence`

use agrr_domain::crop::dtos::{
    CropAiCreateFailure, CropAiCreateOutput, CropCreateInput, CropStageCreateInput,
    HttpStatus, NutrientRequirementUpdateInput, SunshineRequirementUpdateInput,
    TemperatureRequirementUpdateInput, ThermalRequirementUpdateInput,
};
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::crop::interactors::crop_create_interactor::CropCreateInteractor;
use agrr_domain::crop::policies::crop_create_limit_policy;
use agrr_domain::crop::ports::{CreateFailure, CropAiUpsertPersistencePort, CropCreateOutputPort};
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::gateways::UserLookupGateway;
use agrr_domain::shared::policies::crop_policy;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::reference_record_access_filter::ReferenceRecordAccessFilter;
use agrr_domain::shared::reference_record_authorization;
use agrr_domain::shared::user::User;
use serde_json::{json, Map, Value};

pub struct CropAiUpsertSqlitePersistence<G, U, T> {
    crop_gateway: G,
    user_id: i64,
    user_lookup: U,
    translator: T,
}

impl<G, U, T> CropAiUpsertSqlitePersistence<G, U, T> {
    pub fn new(crop_gateway: G, user_id: i64, user_lookup: U, translator: T) -> Self {
        Self {
            crop_gateway,
            user_id,
            user_lookup,
            translator,
        }
    }
}

impl<G, U, T> CropAiUpsertPersistencePort for CropAiUpsertSqlitePersistence<G, U, T>
where
    G: CropGateway,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    fn upsert(
        &self,
        user: &User,
        crop_name: &str,
        variety: Option<&str>,
        crop_info: Value,
        access_filter: ReferenceRecordAccessFilter<agrr_domain::shared::policies::crop_policy::CropRecordAccessPolicy>,
    ) -> Result<CropAiCreateOutput, CropAiCreateFailure> {
        let opts = TranslateOptions::default();

        if let Err(msg) = preflight_user_crop_limit(&self.crop_gateway, user, &self.translator, &opts)
        {
            return Err(CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                msg,
            ));
        }

        if crop_info.get("success") == Some(&Value::Bool(false)) {
            let message = crop_info
                .get("error")
                .and_then(|v| v.as_str())
                .map(str::to_string)
                .unwrap_or_else(|| self.translator.t("api.errors.crops.fetch_failed", &opts));
            return Err(CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                message,
            ));
        }

        let crop_data = crop_info.get("crop").ok_or_else(|| {
            CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                self.translator.t("api.errors.crops.invalid_payload", &opts),
            )
        })?;

        let stage_requirements = crop_info.get("stage_requirements");

        if let Err(e) = validate_stage_requirements(stage_requirements) {
            return Err(CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                e,
            ));
        }

        let existing = find_existing_crop_for_update(
            &self.crop_gateway,
            crop_data,
            &access_filter,
        );

        if let Some(existing_id) = existing {
            update_existing_crop(
                &self.crop_gateway,
                existing_id,
                crop_data,
                variety,
                stage_requirements,
            )
            .map(|crop| CropAiCreateOutput { crop })
            .map_err(|e| {
                CropAiCreateFailure::new(HttpStatus::ServiceUnavailable, e.to_string())
            })
        } else {
            create_new_crop(
                &self.crop_gateway,
                self.user_id,
                &self.user_lookup,
                &self.translator,
                user,
                crop_name,
                crop_data,
                variety,
                stage_requirements,
            )
            .map(|crop| CropAiCreateOutput { crop })
            .map_err(|failure| failure)
        }
    }
}

fn preflight_user_crop_limit<G: CropGateway, T: TranslatorPort>(
    gateway: &G,
    user: &User,
    translator: &T,
    opts: &TranslateOptions,
) -> Result<(), String> {
    let count = gateway
        .count_user_owned_non_reference_crops(user.id)
        .map_err(|e| e.to_string())?;
    if crop_create_limit_policy::limit_exceeded(count, false) {
        return Err(translator.t(
            "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded",
            opts,
        ));
    }
    Ok(())
}

fn find_existing_crop_for_update<G: CropGateway>(
    gateway: &G,
    crop_data: &Value,
    access_filter: &ReferenceRecordAccessFilter<
        agrr_domain::shared::policies::crop_policy::CropRecordAccessPolicy,
    >,
) -> Option<i64> {
    let crop_id = json_crop_id(crop_data.get("crop_id")?)?;
    let entity = gateway.find_by_id(crop_id).ok()?;
    reference_record_authorization::assert_edit_allowed(access_filter, &entity).ok()?;
    Some(crop_id)
}

fn update_existing_crop<G: CropGateway>(
    gateway: &G,
    crop_id: i64,
    crop_data: &Value,
    variety: Option<&str>,
    stage_requirements: Option<&Value>,
) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
    let variety_value = resolve_variety(variety, crop_data.get("variety"), None);
    let groups_json = groups_json_from_crop_data(crop_data);
    let attrs = attr_map_from_pairs([
        ("variety", optional_str_attr(variety_value.as_deref())),
        (
            "area_per_unit",
            json_f64_attr(crop_data.get("area_per_unit")),
        ),
        (
            "revenue_per_area",
            json_f64_attr(crop_data.get("revenue_per_area")),
        ),
        ("groups", AttrValue::Str(groups_json)),
    ]);
    let user = User::new(0, false);
    gateway.update_for_user(&user, crop_id, attrs)?;

    let stages = gateway.list_by_crop_id(crop_id)?;
    for stage in stages {
        gateway.delete_crop_stage(stage.id)?;
    }
    if let Some(requirements) = stage_requirements.and_then(|v| v.as_array()) {
        if !requirements.is_empty() {
            save_crop_stages(gateway, crop_id, requirements)?;
        }
    }
    gateway.find_by_id(crop_id)
}

fn create_new_crop<G, U, T>(
    gateway: &G,
    user_id: i64,
    user_lookup: &U,
    translator: &T,
    user: &User,
    crop_name: &str,
    crop_data: &Value,
    variety: Option<&str>,
    stage_requirements: Option<&Value>,
) -> Result<CropEntity, CropAiCreateFailure>
where
    G: CropGateway,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    let variety_value = resolve_variety(variety, crop_data.get("variety"), None);
    let base_attrs = attr_map_from_pairs([
        ("name", AttrValue::from(crop_name)),
        (
            "variety",
            optional_str_attr(variety_value.as_deref()),
        ),
        (
            "area_per_unit",
            json_f64_attr(crop_data.get("area_per_unit")),
        ),
        (
            "revenue_per_area",
            json_f64_attr(crop_data.get("revenue_per_area")),
        ),
        ("groups", AttrValue::Str(groups_json_from_crop_data(crop_data))),
    ]);
    let attrs = crop_policy::normalize_attrs_for_create(user, base_attrs);

    let mut output = CapturingCreateOutput::default();
    let mut interactor = CropCreateInteractor::new(
        &mut output,
        user_id,
        gateway,
        translator,
        user_lookup,
    );
    let input = CropCreateInput {
        name: crop_name.to_string(),
        variety: variety_value,
        area_per_unit: json_f64(crop_data.get("area_per_unit")),
        revenue_per_area: json_f64(crop_data.get("revenue_per_area")),
        region: None,
        groups: json_groups_vec(crop_data),
        is_reference: attrs
            .get("is_reference")
            .and_then(|v| matches!(v, AttrValue::Bool(b) if *b).then_some(true))
            .unwrap_or(false),
    };

    interactor
        .call(input)
        .map_err(|e| CropAiCreateFailure::new(HttpStatus::ServiceUnavailable, e.to_string()))?;

    let crop_entity = match output.result {
        Some(Ok(entity)) => entity,
        Some(Err(message)) => {
            return Err(CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                message,
            ))
        }
        None => {
            return Err(CropAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                "crop create produced no result",
            ))
        }
    };

    if let Some(requirements) = stage_requirements.and_then(|v| v.as_array()) {
        if !requirements.is_empty() {
            save_crop_stages(gateway, crop_entity.id, requirements).map_err(|e| {
                CropAiCreateFailure::new(HttpStatus::ServiceUnavailable, e.to_string())
            })?;
        }
    }

    gateway.find_by_id(crop_entity.id).map_err(|e| {
        CropAiCreateFailure::new(HttpStatus::ServiceUnavailable, e.to_string())
    })
}

#[derive(Default)]
struct CapturingCreateOutput {
    result: Option<Result<CropEntity, String>>,
}

impl CropCreateOutputPort for CapturingCreateOutput {
    fn on_success(&mut self, entity: CropEntity) {
        self.result = Some(Ok(entity));
    }

    fn on_failure(&mut self, failure: CreateFailure) {
        let message = match failure {
            CreateFailure::Error(e) => e.message,
            CreateFailure::LimitExceeded(f) => f.message,
        };
        self.result = Some(Err(message));
    }
}

fn validate_stage_requirements(stage_requirements: Option<&Value>) -> Result<(), String> {
    let Some(requirements) = stage_requirements.and_then(|v| v.as_array()) else {
        return Ok(());
    };
    if requirements.is_empty() {
        return Ok(());
    }
    for stage_requirement in requirements {
        let stage_info = stage_requirement
            .get("stage")
            .ok_or_else(|| "stage information is required".to_string())?;
        let order = stage_info.get("order");
        if order.is_none() || order.and_then(|v| v.as_str()).is_some_and(|s| s.is_empty()) {
            if order.and_then(|v| v.as_i64()).is_none() {
                return Err("stage order is required".into());
            }
        }
    }
    Ok(())
}

fn save_crop_stages<G: CropGateway>(
    gateway: &G,
    crop_id: i64,
    stages_data: &[Value],
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    for stage_requirement in stages_data {
        let stage_info = stage_requirement
            .get("stage")
            .ok_or("stage information is required")?;
        let name = stage_info
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("stage");
        let order = stage_info
            .get("order")
            .and_then(|v| v.as_i64())
            .unwrap_or(0) as i32;
        let stage = gateway.create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": name, "order": order }),
        ))?;

        if let Some(temp) = stage_requirement.get("temperature").filter(|v| !v.is_null()) {
            if let Some(obj) = temp.as_object().filter(|m| !m.is_empty()) {
                gateway.create_temperature_requirement(
                    stage.id,
                    TemperatureRequirementUpdateInput::new(
                        crop_id,
                        stage.id,
                        json!({ "temperature_requirement": obj }),
                    ),
                )?;
            }
        }

        if let Some(sun) = stage_requirement.get("sunshine").filter(|v| !v.is_null()) {
            if let Some(obj) = sun.as_object().filter(|m| !m.is_empty()) {
                gateway.create_sunshine_requirement(
                    stage.id,
                    SunshineRequirementUpdateInput::new(
                        crop_id,
                        stage.id,
                        json!({ "sunshine_requirement": obj }),
                    ),
                )?;
            }
        }

        if let Some(thermal) = stage_requirement.get("thermal").filter(|v| !v.is_null()) {
            if let Some(obj) = thermal.as_object().filter(|m| !m.is_empty()) {
                gateway.create_thermal_requirement(
                    stage.id,
                    ThermalRequirementUpdateInput::new(
                        crop_id,
                        stage.id,
                        json!({ "thermal_requirement": obj }),
                    ),
                )?;
            }
        }

        if let Some(nutrients) = stage_requirement.get("nutrients").and_then(|v| v.as_object()) {
            if let Some(daily) = nutrients.get("daily_uptake").and_then(|v| v.as_object()) {
                if !daily.is_empty() {
                    let mut req = Map::new();
                    if let Some(n) = daily.get("N").or_else(|| daily.get("n")) {
                        req.insert("daily_uptake_n".into(), n.clone());
                    }
                    if let Some(p) = daily.get("P").or_else(|| daily.get("p")) {
                        req.insert("daily_uptake_p".into(), p.clone());
                    }
                    if let Some(k) = daily.get("K").or_else(|| daily.get("k")) {
                        req.insert("daily_uptake_k".into(), k.clone());
                    }
                    gateway.create_nutrient_requirement(
                        stage.id,
                        NutrientRequirementUpdateInput::new(
                            crop_id,
                            stage.id,
                            json!({ "nutrient_requirement": req }),
                        ),
                    )?;
                }
            }
        }
    }
    Ok(())
}

fn json_crop_id(value: &Value) -> Option<i64> {
    match value {
        Value::Number(n) => n.as_i64(),
        Value::String(s) if !s.trim().is_empty() => s.trim().parse().ok(),
        Value::Null => None,
        _ => None,
    }
}

fn resolve_variety(
    request_variety: Option<&str>,
    crop_variety: Option<&Value>,
    fallback: Option<&str>,
) -> Option<String> {
    if let Some(v) = request_variety.filter(|s| !s.is_empty()) {
        return Some(v.to_string());
    }
    if let Some(v) = crop_variety.and_then(|x| x.as_str()).filter(|s| !s.is_empty()) {
        return Some(v.to_string());
    }
    fallback.map(str::to_string)
}

fn groups_json_from_crop_data(crop_data: &Value) -> String {
    serde_json::to_string(&json_groups_vec(crop_data)).unwrap_or_else(|_| "[]".into())
}

fn json_groups_vec(crop_data: &Value) -> Vec<String> {
    crop_data
        .get("groups")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default()
}

fn json_f64(value: Option<&Value>) -> Option<f64> {
    value.and_then(|v| v.as_f64())
}

fn json_f64_attr(value: Option<&Value>) -> AttrValue {
    json_f64(value)
        .map(|v| AttrValue::Str(v.to_string()))
        .unwrap_or(AttrValue::Null)
}

fn optional_str_attr(value: Option<&str>) -> AttrValue {
    value
        .map(AttrValue::from)
        .unwrap_or(AttrValue::Null)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::CropSqliteGateway;
    use crate::pool::SqlitePool;
    use agrr_domain::crop::ports::CropAiUpsertPersistencePort;
    use agrr_domain::shared::gateways::UserLookupGateway;
    use agrr_domain::shared::policies::crop_policy;
    use agrr_domain::shared::ports::translator_port::TranslateOptions;

    struct FixedUserLookup(User);
    impl UserLookupGateway for FixedUserLookup {
        fn find(&self, _: i64) -> User {
            self.0.clone()
        }
    }

    struct PassthroughTranslator;
    impl TranslatorPort for PassthroughTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.into()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    fn temp_crop_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_crop_ai_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "crop_ai_{}.sqlite3",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE crops (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   user_id INTEGER, name TEXT NOT NULL, variety TEXT,
                   is_reference INTEGER NOT NULL DEFAULT 0,
                   area_per_unit REAL, revenue_per_area REAL,
                   region TEXT, groups TEXT,
                   created_at TEXT, updated_at TEXT
                 );
                 CREATE TABLE crop_stages (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   crop_id INTEGER NOT NULL, name TEXT, \"order\" INTEGER,
                   created_at TEXT, updated_at TEXT
                 );
                 CREATE TABLE temperature_requirements (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   crop_stage_id INTEGER NOT NULL,
                   base_temperature REAL, optimal_min REAL, optimal_max REAL,
                   low_stress_threshold REAL, high_stress_threshold REAL,
                   frost_threshold REAL, sterility_risk_threshold REAL,
                   max_temperature REAL,
                   created_at TEXT, updated_at TEXT
                 );
                 CREATE TABLE thermal_requirements (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   crop_stage_id INTEGER NOT NULL,
                   required_gdd REAL,
                   created_at TEXT, updated_at TEXT
                 );
                 CREATE TABLE sunshine_requirements (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   crop_stage_id INTEGER NOT NULL,
                   minimum_sunshine_hours REAL, target_sunshine_hours REAL,
                   created_at TEXT, updated_at TEXT
                 );
                 CREATE TABLE nutrient_requirements (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   crop_stage_id INTEGER NOT NULL,
                   daily_uptake_n REAL, daily_uptake_p REAL, daily_uptake_k REAL,
                   region TEXT,
                   created_at TEXT, updated_at TEXT
                 );",
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn upsert_creates_crop_when_agrr_payload_valid() {
        let pool = temp_crop_pool();
        let gateway = CropSqliteGateway::new(pool);
        let user = User::new(7, false);
        let persistence = CropAiUpsertSqlitePersistence::new(
            gateway,
            7,
            FixedUserLookup(user.clone()),
            PassthroughTranslator,
        );
        let crop_info = json!({
            "success": true,
            "crop": {
                "crop_id": null,
                "name": "ブロッコリー",
                "variety": "スプラウト",
                "area_per_unit": 10.0,
                "revenue_per_area": 2000.0,
                "groups": ["leafy"]
            },
            "stage_requirements": []
        });
        let filter = crop_policy::record_access_filter(user.clone());
        let out = persistence
            .upsert(&user, "ブロッコリー", Some("スプラウト"), crop_info, filter)
            .unwrap();
        assert_eq!(out.crop.name, "ブロッコリー");
        assert_eq!(out.crop.variety.as_deref(), Some("スプラウト"));
        assert!((out.crop.area_per_unit.unwrap() - 10.0).abs() < f64::EPSILON);
    }

    #[test]
    fn upsert_returns_failure_when_agrr_success_false() {
        let pool = temp_crop_pool();
        let gateway = CropSqliteGateway::new(pool);
        let user = User::new(7, false);
        let persistence = CropAiUpsertSqlitePersistence::new(
            gateway,
            7,
            FixedUserLookup(user.clone()),
            PassthroughTranslator,
        );
        let crop_info = json!({ "success": false, "error": "not found" });
        let filter = crop_policy::record_access_filter(user.clone());
        let err = persistence
            .upsert(&user, "x", None, crop_info, filter)
            .unwrap_err();
        assert_eq!(err.http_status, HttpStatus::UnprocessableEntity);
        assert_eq!(err.message, "not found");
    }
}
