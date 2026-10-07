//! Ruby: `Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor`

use serde_json::{json, Value};
use time::Date;

use crate::field_cultivation::helpers::parse_iso_date;
use crate::field_cultivation::dtos::{
    FieldCultivationClimateDataInput, FieldCultivationClimateDataOutput,
    FieldCultivationClimateSourceSnapshot,
};
use crate::field_cultivation::errors::{
    PlanPredictionNotGeneratedError, PredictionPayloadMissingError, WeatherPayloadInvalidError,
};
use crate::field_cultivation::gateways::{
    FieldCultivationClimateProgressGateway, FieldCultivationClimateSourceGateway,
    FieldCultivationCropGateway, FieldCultivationWeatherDataGateway,
};
use crate::weather_data::dtos::PredictedWeatherScope;
use crate::weather_data::gateways::PredictedWeatherStoreGateway;
use crate::field_cultivation::interactors::plan_field_cultivation_authorization::{
    assert_field_cultivation_plan_access, assert_public_field_cultivation_plan_access,
};
use crate::field_cultivation::mappers::{
    build_observed_agrr_payload, build_output, climate_crop_agrr_requirement_from_entity,
    extract_weather_records, merge_cached_with_observed, to_context_snapshot, valid_weather_payload,
    weather_location_meta_from_source,
};
use crate::field_cultivation::policies::{
    climate_crop_view_allowed, missing_cultivation_period, missing_weather_location,
    resolve_observed_merge_range,
};
use crate::field_cultivation::ports::{
    FieldCultivationClimateDataInputPort, FieldCultivationClimateDataOutputPort,
};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use crate::shared::validation::to_array_value;
use std::collections::BTreeMap;

pub struct FieldCultivationClimateDataInteractor<'a> {
    output_port: &'a mut dyn FieldCultivationClimateDataOutputPort,
    logger: &'a dyn LoggerPort,
    user_id: Option<i64>,
    user_lookup: Option<&'a dyn UserLookupGateway>,
    climate_source_gateway: &'a dyn FieldCultivationClimateSourceGateway,
    crop_gateway: &'a dyn FieldCultivationCropGateway,
    weather_data_gateway: &'a dyn FieldCultivationWeatherDataGateway,
    predicted_weather_store_gateway: &'a dyn PredictedWeatherStoreGateway,
    climate_progress_gateway: &'a dyn FieldCultivationClimateProgressGateway,
    clock: &'a dyn ClockPort,
    translator: &'a dyn TranslatorPort,
}

impl<'a> FieldCultivationClimateDataInteractor<'a> {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut dyn FieldCultivationClimateDataOutputPort,
        logger: &'a dyn LoggerPort,
        user_id: Option<i64>,
        user_lookup: Option<&'a dyn UserLookupGateway>,
        climate_source_gateway: &'a dyn FieldCultivationClimateSourceGateway,
        crop_gateway: &'a dyn FieldCultivationCropGateway,
        weather_data_gateway: &'a dyn FieldCultivationWeatherDataGateway,
        predicted_weather_store_gateway: &'a dyn PredictedWeatherStoreGateway,
        climate_progress_gateway: &'a dyn FieldCultivationClimateProgressGateway,
        clock: &'a dyn ClockPort,
        translator: &'a dyn TranslatorPort,
    ) -> Self {
        Self {
            output_port,
            logger,
            user_id,
            user_lookup,
            climate_source_gateway,
            crop_gateway,
            weather_data_gateway,
            predicted_weather_store_gateway,
            climate_progress_gateway,
            clock,
            translator,
        }
    }
}

impl FieldCultivationClimateDataInteractor<'_> {
    fn handle_policy_denied(&mut self) {
        self.output_port.on_error(Error::new("Forbidden"));
    }

    fn handle_domain_error(&mut self, message: impl Into<String>) {
        self.output_port.on_error(Error::new(message));
    }
}

impl FieldCultivationClimateDataInputPort for FieldCultivationClimateDataInteractor<'_> {
    fn call(
        &mut self,
        input: FieldCultivationClimateDataInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user_dto = match (self.user_id, self.user_lookup) {
            (Some(id), Some(lookup)) => Some(lookup.find(id)),
            _ => None,
        };

        let plan_access_snapshot = match self
            .climate_source_gateway
            .find_plan_access_snapshot_by_field_cultivation_id(input.field_cultivation_id)
        {
            Ok(snapshot) => snapshot,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn(&format!(
                    "[FieldCultivationClimateDataInteractor] Field cultivation not found: {err}"
                ));
                self.handle_domain_error(err.to_string());
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let Some(ref user) = user_dto {
            if let Err(err) = assert_field_cultivation_plan_access(
                user,
                &plan_access_snapshot,
                false,
            ) {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.handle_policy_denied();
                    return Ok(());
                }
                return Err(err);
            }
        } else if let Err(err) =
            assert_public_field_cultivation_plan_access(&plan_access_snapshot)
        {
            if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                self.handle_policy_denied();
                return Ok(());
            }
            return Err(err);
        }

        let source = match self
            .climate_source_gateway
            .find_climate_source_snapshot_by_field_cultivation_id(input.field_cultivation_id)
        {
            Ok(snapshot) => snapshot,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn(&format!(
                    "[FieldCultivationClimateDataInteractor] Field cultivation not found: {err}"
                ));
                self.handle_domain_error(err.to_string());
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let Some(message) = climate_precondition_failure_message(self.translator, &source) {
            self.logger.warn(&format!(
                "[FieldCultivationClimateDataInteractor] Climate precondition: {message}"
            ));
            self.handle_domain_error(message);
            return Ok(());
        }

        let crop_entity = match resolve_crop_entity(
            self.crop_gateway,
            &source,
            user_dto.as_ref(),
        ) {
            Ok(Some(c)) => c,
            Ok(None) => {
                self.handle_domain_error(self.translator.t(
                    "api.errors.crop_not_found",
                    &BTreeMap::new(),
                ));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let context = to_context_snapshot(&source, &crop_entity);

        let climate_data = match assemble_climate_data(self, &source, &context, &crop_entity) {
            Ok(data) => data,
            Err(err)
                if err.downcast_ref::<PlanPredictionNotGeneratedError>().is_some()
                    || err.downcast_ref::<PredictionPayloadMissingError>().is_some()
                    || err.downcast_ref::<WeatherPayloadInvalidError>().is_some() =>
            {
                self.logger.warn(&format!(
                    "[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id={}: {:?}",
                    input.field_cultivation_id,
                    err
                ));
                self.handle_domain_error("Field cultivation climate data not found");
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let filtered = apply_display_range(
            climate_data,
            input.display_start_date.as_deref(),
            input.display_end_date.as_deref(),
        );
        self.output_port.present(filtered);
        Ok(())
    }
}

fn climate_precondition_failure_message(
    translator: &dyn TranslatorPort,
    source: &FieldCultivationClimateSourceSnapshot,
) -> Option<String> {
    let opts = &BTreeMap::new();
    if missing_weather_location(source.weather_location_id) {
        return Some(translator.t("api.errors.no_weather_data", opts));
    }
    if missing_cultivation_period(source.start_date, source.completion_date) {
        return Some(translator.t("api.errors.no_cultivation_period", opts));
    }
    None
}

fn resolve_crop_entity(
    crop_gateway: &dyn FieldCultivationCropGateway,
    source: &FieldCultivationClimateSourceSnapshot,
    user_dto: Option<&crate::shared::user::User>,
) -> Result<Option<crate::field_cultivation::dtos::ClimateCropEntity>, Box<dyn std::error::Error + Send + Sync>>
{
    let Some(crop_id) = source.plan_crop_crop_id else {
        return Ok(None);
    };
    let crop_entity = match crop_gateway.find_by_id(crop_id) {
        Ok(e) => e,
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => return Ok(None),
        Err(err) => return Err(err),
    };
    if climate_crop_view_allowed(user_dto, &crop_entity, source.plan_type_public) {
        Ok(Some(crop_entity))
    } else {
        Ok(None)
    }
}

fn assemble_climate_data(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    source: &FieldCultivationClimateSourceSnapshot,
    context: &crate::field_cultivation::dtos::FieldCultivationClimateContextSnapshot,
    crop_entity: &crate::field_cultivation::dtos::ClimateCropEntity,
) -> Result<FieldCultivationClimateDataOutput, Box<dyn std::error::Error + Send + Sync>> {
    let weather_payload = fetch_plan_weather_payload(interactor, source, context)?;
    Ok(build_climate_output(
        interactor,
        context,
        crop_entity,
        &weather_payload,
    ))
}

fn build_climate_output(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    context: &crate::field_cultivation::dtos::FieldCultivationClimateContextSnapshot,
    crop_entity: &crate::field_cultivation::dtos::ClimateCropEntity,
    weather_payload: &Value,
) -> FieldCultivationClimateDataOutput {
    let weather_records = extract_weather_records(
        Some(weather_payload),
        context.start_date,
        context.completion_date,
    );
    let crop_requirement = climate_crop_agrr_requirement_from_entity(crop_entity);
    let progress_result = interactor
        .climate_progress_gateway
        .calculate_progress(&crop_requirement, context.start_date, weather_payload)
        .unwrap_or_else(|_| json!({ "progress_records": [] }));
    build_output(context, &weather_records, &progress_result)
}

fn fetch_plan_weather_payload(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    source: &FieldCultivationClimateSourceSnapshot,
    context: &crate::field_cultivation::dtos::FieldCultivationClimateContextSnapshot,
) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
    if !context.plan_predicted_weather_present {
        interactor.logger.warn(&format!(
            "⚠️ [FieldCultivationClimateDataInteractor] No cached prediction for CultivationPlan#{}",
            context.plan_id
        ));
        return Err(Box::new(PlanPredictionNotGeneratedError));
    }
    interactor.logger.info(&format!(
        "✅ [FieldCultivationClimateDataInteractor] Using saved prediction for CultivationPlan#{}, merging with observed data",
        context.plan_id
    ));
    let cached = load_plan_prediction_payload(interactor, context)?;
    let Some(cached) = cached else {
        return Err(Box::new(PredictionPayloadMissingError));
    };
    let weather_payload = merge_cached_prediction_with_observed(
        interactor,
        source,
        context,
        cached,
    )?;
    assert_valid_weather_payload(interactor, context.plan_id, &weather_payload)?;
    Ok(weather_payload)
}

fn merge_cached_prediction_with_observed(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    source: &FieldCultivationClimateSourceSnapshot,
    context: &crate::field_cultivation::dtos::FieldCultivationClimateContextSnapshot,
    cached: Value,
) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
    let decision = resolve_observed_merge_range(
        Some(context.start_date),
        Some(context.completion_date),
        interactor.clock.today(),
    );
    if decision.skip_merge() {
        return Ok(cached);
    }
    let start = decision.start_date.unwrap();
    let end = decision.end_date.unwrap();
    let weather_location_id = source.weather_location_id.unwrap();
    let observed_dtos = interactor
        .weather_data_gateway
        .weather_data_for_period(weather_location_id, start, end)?;
    let meta = weather_location_meta_from_source(source);
    let observed_formatted = build_observed_agrr_payload(&meta, &observed_dtos);
    Ok(merge_cached_with_observed(&cached, &observed_formatted))
}

fn load_plan_prediction_payload(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    context: &crate::field_cultivation::dtos::FieldCultivationClimateContextSnapshot,
) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
    if context.plan_metadata.is_none() {
        return Ok(None);
    }
    interactor
        .predicted_weather_store_gateway
        .read_payload(PredictedWeatherScope::Plan, context.plan_id)
}

fn assert_valid_weather_payload(
    interactor: &FieldCultivationClimateDataInteractor<'_>,
    plan_id: i64,
    weather_payload: &Value,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if valid_weather_payload(Some(weather_payload)) {
        return Ok(());
    }
    interactor.logger.error(&format!(
        "❌ [FieldCultivationClimateDataInteractor] Invalid weather payload for CultivationPlan#{plan_id}"
    ));
    Err(Box::new(WeatherPayloadInvalidError))
}

fn apply_display_range(
    climate_data: FieldCultivationClimateDataOutput,
    display_start_date: Option<&str>,
    display_end_date: Option<&str>,
) -> FieldCultivationClimateDataOutput {
    if display_start_date.is_none() && display_end_date.is_none() {
        return climate_data;
    }
    let gantt_start = display_start_date.and_then(|s| parse_date(s));
    let gantt_end = display_end_date.and_then(|s| parse_date(s));
    let (Some(gantt_start), Some(gantt_end)) = (gantt_start, gantt_end) else {
        return climate_data;
    };

    let cultivation_start = climate_data
        .field_cultivation
        .get("start_date")
        .and_then(|v| v.as_str())
        .and_then(parse_date);
    let cultivation_end = climate_data
        .field_cultivation
        .get("completion_date")
        .and_then(|v| v.as_str())
        .and_then(parse_date);

    let mut effective_start = match (cultivation_start, Some(gantt_start)) {
        (Some(a), Some(b)) => a.max(b),
        (Some(a), None) => a,
        (None, Some(b)) => b,
        (None, None) => gantt_start,
    };
    let mut effective_end = match (cultivation_end, Some(gantt_end)) {
        (Some(a), Some(b)) => a.min(b),
        (Some(a), None) => a,
        (None, Some(b)) => b,
        (None, None) => gantt_end,
    };

    if effective_start > effective_end {
        effective_start = gantt_start;
        effective_end = gantt_end;
    }

    let filtered_weather =
        filter_weather_data(&climate_data.weather_data, effective_start, effective_end);
    let filtered_gdd = filter_gdd_data(&climate_data.gdd_data, effective_start, effective_end);

    let mut field_cultivation = climate_data.field_cultivation;
    if let Some(obj) = field_cultivation.as_object_mut() {
        obj.insert(
            "start_date".into(),
            json!(effective_start.to_string()),
        );
        obj.insert(
            "completion_date".into(),
            json!(effective_end.to_string()),
        );
    }

    let mut debug_info = climate_data.debug_info;
    if let Some(obj) = debug_info.as_object_mut() {
        obj.insert(
            "display_range".into(),
            json!({
                "gantt_start": gantt_start.to_string(),
                "gantt_end": gantt_end.to_string(),
                "cultivation_start": cultivation_start.map(|d| d.to_string()),
                "cultivation_end": cultivation_end.map(|d| d.to_string()),
                "effective_start": effective_start.to_string(),
                "effective_end": effective_end.to_string(),
                "weather_records": filtered_weather.len(),
                "gdd_records": filtered_gdd.len(),
                "note": "All components use intersection of cultivation period and gantt chart bounds",
            }),
        );
    }

    FieldCultivationClimateDataOutput {
        field_cultivation,
        farm: climate_data.farm,
        crop_requirements: climate_data.crop_requirements,
        weather_data: filtered_weather,
        gdd_data: filtered_gdd,
        stages: climate_data.stages,
        progress_result: climate_data.progress_result,
        debug_info,
    }
}

fn filter_weather_data(data: &[Value], range_start: Date, range_end: Date) -> Vec<Value> {
    to_array_value(Some(&Value::Array(data.to_vec())))
        .into_iter()
        .filter(|datum| {
            let Some(date_value) = datum
                .get("date")
                .and_then(|v| v.as_str())
                .and_then(parse_date)
            else {
                return false;
            };
            date_value >= range_start && date_value <= range_end
        })
        .collect()
}

fn filter_gdd_data(data: &[Value], range_start: Date, range_end: Date) -> Vec<Value> {
    to_array_value(Some(&Value::Array(data.to_vec())))
        .into_iter()
        .filter(|datum| {
            let Some(date_value) = datum
                .get("date")
                .and_then(|v| v.as_str())
                .and_then(parse_date)
            else {
                return false;
            };
            date_value >= range_start && date_value <= range_end
        })
        .collect()
}

fn parse_date(value: &str) -> Option<Date> {
    parse_iso_date(value)
}

#[cfg(test)]
mod interactors_field_cultivation_climate_data_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/field_cultivation/interactors_field_cultivation_climate_data_interactor_test.rs"
    ));
}
