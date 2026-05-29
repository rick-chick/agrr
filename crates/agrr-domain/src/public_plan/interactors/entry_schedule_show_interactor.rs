//! Ruby: `Domain::PublicPlan::Interactors::EntryScheduleShowInteractor`

use std::collections::BTreeMap;

use serde_json::Value;
use time::Date;

use crate::public_plan::dtos::{EntryScheduleFailure, EntryScheduleShowOutput};
use crate::public_plan::exceptions::{
    PredictionPayloadMissingError, WeatherLocationMissingError, WeatherPredictionFailedError,
};
use crate::public_plan::mappers::entry_schedule_crop_mapper::{
    self, EntryScheduleCropLike, EntryScheduleFarmLike, EntryScheduleWindowResult,
};
use crate::public_plan::ports::{EntryScheduleCropGateway, EntryScheduleShowOutputPort};
use crate::shared::ports::{ClockPort, TranslatorPort};

/// Weather payload loader (Ruby: `@weather_loader`).
pub trait EntryScheduleWeatherLoaderPort: Send + Sync {
    fn load_prediction_payload(
        &self,
        farm: &dyn EntryScheduleShowFarm,
        prediction_end_date_raw: Option<&str>,
        reference_date: Date,
    ) -> Result<BTreeMap<String, Value>, Box<dyn std::error::Error + Send + Sync>>;
}

/// Optimization runner (Ruby: `@optimization_runner`).
pub trait EntryScheduleOptimizationRunnerPort: Send + Sync {
    fn call(
        &self,
        crop: &dyn EntryScheduleShowCrop,
        weather_payload: &BTreeMap<String, Value>,
        farm: &dyn EntryScheduleShowFarm,
    ) -> EntryScheduleWindowResult;
}

/// Farm input for entry schedule show.
pub trait EntryScheduleShowFarm: EntryScheduleFarmLike {
    fn id(&self) -> i64;
    fn name(&self) -> &str;
    fn latitude(&self) -> f64;
    fn longitude(&self) -> f64;
    fn region(&self) -> &str;
}

/// Crop input for entry schedule show.
pub trait EntryScheduleShowCrop: EntryScheduleCropLike {}

/// Ruby: `Domain::PublicPlan::Interactors::EntryScheduleShowInteractor`
pub struct EntryScheduleShowInteractor<'a, O, CG, W, R, T, C> {
    output_port: &'a mut O,
    crop_gateway: &'a CG,
    weather_loader: &'a W,
    optimization_runner: &'a R,
    translator: &'a T,
    clock: &'a C,
}

impl<'a, O, CG, W, R, T, C> EntryScheduleShowInteractor<'a, O, CG, W, R, T, C>
where
    O: EntryScheduleShowOutputPort,
    CG: EntryScheduleCropGateway,
    W: EntryScheduleWeatherLoaderPort,
    R: EntryScheduleOptimizationRunnerPort,
    T: TranslatorPort,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a CG,
        weather_loader: &'a W,
        optimization_runner: &'a R,
        translator: &'a T,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            weather_loader,
            optimization_runner,
            translator,
            clock,
        }
    }

    /// Ruby: `#call(farm:, crop:, reference_date:, prediction_end_date_raw:)`
    pub fn call(
        &mut self,
        farm: &dyn EntryScheduleShowFarm,
        crop: &dyn EntryScheduleShowCrop,
        reference_date: Date,
        prediction_end_date_raw: Option<&str>,
    ) {
        let payload_hash = match self.weather_loader.load_prediction_payload(
            farm,
            prediction_end_date_raw,
            reference_date,
        ) {
            Ok(hash) => hash,
            Err(err) => {
                if err.downcast_ref::<WeatherLocationMissingError>().is_some() {
                    self.output_port
                        .on_failure(EntryScheduleFailure::weather_location_required());
                } else if err.downcast_ref::<PredictionPayloadMissingError>().is_some() {
                    self.output_port
                        .on_failure(EntryScheduleFailure::prediction_payload_missing());
                } else if let Some(e) = err.downcast_ref::<WeatherPredictionFailedError>() {
                    self.output_port.on_failure(
                        EntryScheduleFailure::weather_prediction_failed(e.0.clone()),
                    );
                } else {
                    self.output_port
                        .on_failure(EntryScheduleFailure::internal_error(err.to_string()));
                }
                return;
            }
        };

        let result = self
            .optimization_runner
            .call(crop, &payload_hash, farm);
        let crop_stages = self.crop_gateway.list_by_crop_id(crop.id());
        let crop_detail = entry_schedule_crop_mapper::crop_detail(
            crop,
            &result,
            self.translator,
            &crop_stages,
            self.clock,
        );
        let prediction_meta = entry_schedule_crop_mapper::prediction_meta(
            farm,
            &payload_hash,
            reference_date.year(),
        );

        let mut farm_fragment = BTreeMap::new();
        farm_fragment.insert("id".into(), Value::from(farm.id()));
        farm_fragment.insert("name".into(), Value::from(farm.name()));
        farm_fragment.insert("latitude".into(), Value::from(farm.latitude()));
        farm_fragment.insert("longitude".into(), Value::from(farm.longitude()));
        farm_fragment.insert("region".into(), Value::from(farm.region()));

        self.output_port.on_success(EntryScheduleShowOutput::new(
            farm_fragment,
            prediction_meta,
            crop_detail,
        ));
    }
}

#[cfg(test)]
mod interactors_entry_schedule_show_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/public_plan/interactors_entry_schedule_show_interactor_test.rs"));
}
