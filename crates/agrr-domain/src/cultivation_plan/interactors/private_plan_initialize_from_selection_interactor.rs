//! Ruby: `Domain::CultivationPlan::Interactors::PrivatePlanInitializeFromSelectionInteractor`

use time::{Date, Month};

use crate::crop::entities::CropEntity;
use crate::cultivation_plan::dtos::{
    CultivationPlanInitCrop, CultivationPlanInitFarm, PrivatePlanInitializeFromSelectionFailure,
    PrivatePlanInitializeFromSelectionInput, PrivatePlanInitializeFromSelectionOutput,
};
use crate::cultivation_plan::ports::{
    PrivatePlanCropListGateway, PrivatePlanExistingPlanGateway, PrivatePlanFarmResolveGateway,
    PrivatePlanInitializeCallablePort, PrivatePlanInitializeFromSelectionOutputPort,
    PrivatePlanOptimizationJobChainGateway, PrivatePlanSessionIdGeneratorPort,
};
use crate::field::gateways::FieldGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::helpers::date_calendar::beginning_of_year;
use crate::shared::policies::crop_policy;
use crate::shared::policies::farm_policy;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

pub struct PrivatePlanInitializeFromSelectionInteractor<'a, O, EP, F, C, FG, I, L, T, Ck, J> {
    output_port: &'a mut O,
    cultivation_plan_gateway: &'a EP,
    farm_gateway: &'a F,
    crop_gateway: &'a C,
    field_gateway: &'a FG,
    plan_initializer: &'a I,
    logger: &'a L,
    translator: &'a T,
    clock: &'a Ck,
    session_id_generator: &'a dyn PrivatePlanSessionIdGeneratorPort,
    job_chain_enqueuer: &'a J,
}

impl<'a, O, EP, F, C, FG, I, L, T, Ck, J>
    PrivatePlanInitializeFromSelectionInteractor<'a, O, EP, F, C, FG, I, L, T, Ck, J>
where
    O: PrivatePlanInitializeFromSelectionOutputPort,
    EP: PrivatePlanExistingPlanGateway,
    F: PrivatePlanFarmResolveGateway,
    C: PrivatePlanCropListGateway,
    FG: FieldGateway,
    I: PrivatePlanInitializeCallablePort,
    L: LoggerPort,
    T: TranslatorPort,
    Ck: ClockPort,
    J: PrivatePlanOptimizationJobChainGateway,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut O,
        cultivation_plan_gateway: &'a EP,
        farm_gateway: &'a F,
        crop_gateway: &'a C,
        field_gateway: &'a FG,
        plan_initializer: &'a I,
        logger: &'a L,
        translator: &'a T,
        clock: &'a Ck,
        session_id_generator: &'a dyn PrivatePlanSessionIdGeneratorPort,
        job_chain_enqueuer: &'a J,
    ) -> Self {
        Self {
            output_port,
            cultivation_plan_gateway,
            farm_gateway,
            crop_gateway,
            field_gateway,
            plan_initializer,
            logger,
            translator,
            clock,
            session_id_generator,
            job_chain_enqueuer,
        }
    }

    pub fn call(
        &mut self,
        input: &PrivatePlanInitializeFromSelectionInput,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Err(err) = self.call_inner(input) {
            if err.downcast_ref::<RecordInvalidError>().is_some() {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.error(&format!(
                    "❌ [PrivatePlanInitializeFromSelectionInteractor] RecordInvalid: {}",
                    invalid
                ));
                self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                    PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                    invalid.to_string(),
                ));
                return Ok(());
            }
            return Err(err);
        }
        Ok(())
    }

    fn call_inner(
        &mut self,
        input: &PrivatePlanInitializeFromSelectionInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let crop_ids = input.normalized_crop_ids();
        if crop_ids.is_empty() {
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                self.translator.t("plans.errors.select_crop", &Default::default()),
            ));
            return Ok(());
        }

        let farm = match self.resolve_owned_farm(input)? {
            Some(farm) => farm,
            None => {
                self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                    PrivatePlanInitializeFromSelectionFailure::HTTP_NOT_FOUND,
                    self.translator.t("plans.errors.not_found", &Default::default()),
                ));
                return Ok(());
            }
        };

        let crops = match self.resolve_private_plan_crops(input, &crop_ids)? {
            Some(crops) => crops,
            None => {
                self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                    PrivatePlanInitializeFromSelectionFailure::HTTP_NOT_FOUND,
                    self.translator.t("plans.errors.not_found", &Default::default()),
                ));
                return Ok(());
            }
        };

        if self
            .cultivation_plan_gateway
            .find_existing(farm.id, input.user.id)?
            .is_some()
        {
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                self.translator.t("plans.errors.plan_already_exists_annual", &Default::default()),
            ));
            return Ok(());
        }

        let plan_name = input
            .plan_name
            .as_deref()
            .filter(|n| !n.trim().is_empty())
            .unwrap_or(&farm.name)
            .to_string();
        let session_id = self.session_id_generator.generate();
        let total_area = self.field_gateway.get_total_area_by_farm_id(farm.id)?;
        let today = self.clock.today();
        let planning_start_date = beginning_of_year(today);
        let planning_end_date = Date::from_calendar_date(today.year() + 1, Month::December, 31)
            .expect("valid end of year");

        let init_farm = CultivationPlanInitFarm {
            id: farm.id,
            name: farm.name.clone(),
        };
        let init_crops: Vec<CultivationPlanInitCrop> = crops
            .iter()
            .map(crop_entity_to_init_crop)
            .collect();

        let result = self.plan_initializer.call(
            &init_farm,
            total_area,
            &init_crops,
            input.user.id,
            &session_id,
            &plan_name,
            planning_start_date,
            planning_end_date,
        )?;

        let Some(plan) = result.cultivation_plan else {
            let msg = if result.errors.is_empty() {
                self.translator
                    .t("public_plans.save.error", &Default::default())
            } else {
                result.errors.join(", ")
            };
            self.logger
                .error(&format!("❌ [PrivatePlanInitializeFromSelectionInteractor] Initialize failed: {msg}"));
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                msg,
            ));
            return Ok(());
        };

        let plan_id = plan.id;
        self.logger.info(&format!(
            "✅ [PrivatePlanInitializeFromSelectionInteractor] CultivationPlan created: {plan_id}"
        ));

        self.job_chain_enqueuer.enqueue_after_create(plan_id)?;
        self.output_port
            .on_success(PrivatePlanInitializeFromSelectionOutput { id: plan_id });
        Ok(())
    }

    fn resolve_owned_farm(
        &self,
        input: &PrivatePlanInitializeFromSelectionInput,
    ) -> Result<Option<CultivationPlanInitFarm>, Box<dyn std::error::Error + Send + Sync>> {
        let farm = match self.farm_gateway.find_by_id(input.farm_id) {
            Ok(farm) => farm,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => return Ok(None),
            Err(err) => return Err(err),
        };

        if !farm_policy::owned_visible(&input.user, farm.is_reference, farm.user_id) {
            return Ok(None);
        }

        Ok(Some(CultivationPlanInitFarm {
            id: farm.id,
            name: farm.name,
        }))
    }

    fn resolve_private_plan_crops(
        &self,
        input: &PrivatePlanInitializeFromSelectionInput,
        requested_ids: &[i64],
    ) -> Result<Option<Vec<CropEntity>>, Box<dyn std::error::Error + Send + Sync>> {
        if requested_ids.is_empty() {
            return Ok(Some(vec![]));
        }

        let entities = self.crop_gateway.list_by_ids(requested_ids)?;
        let accessible: Vec<CropEntity> = entities
            .into_iter()
            .filter(|crop| {
                crop_policy::edit_allowed(&input.user, crop.is_reference, crop.user_id)
            })
            .collect();

        let mut accessible_ids: Vec<i64> = accessible.iter().map(|c| c.id).collect();
        accessible_ids.sort_unstable();

        let mut expected = requested_ids.to_vec();
        expected.sort_unstable();

        if accessible_ids != expected {
            return Ok(None);
        }

        Ok(Some(accessible))
    }
}

fn crop_entity_to_init_crop(crop: &CropEntity) -> CultivationPlanInitCrop {
    CultivationPlanInitCrop {
        id: crop.id,
        name: crop.name.clone(),
        variety: crop.variety.clone(),
        area_per_unit: crop.area_per_unit.unwrap_or(0.0),
        revenue_per_area: crop.revenue_per_area.unwrap_or(0.0),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::CultivationPlanInitializeResult;
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use crate::farm::entities::FarmEntity;
    use crate::shared::ports::translator_port::TranslateOptions;
    use crate::shared::user::User;
    use std::sync::{Arc, Mutex};
    use time::macros::date;

    struct FakeTranslator;
    impl TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            date!(2026-06-15)
        }
        fn now(&self) -> time::OffsetDateTime {
            time::macros::datetime!(2026-06-15 12:00 UTC)
        }
    }

    struct SpyOutput {
        success: Arc<Mutex<Vec<i64>>>,
        failures: Arc<Mutex<Vec<PrivatePlanInitializeFromSelectionFailure>>>,
    }

    impl PrivatePlanInitializeFromSelectionOutputPort for SpyOutput {
        fn on_success(&mut self, dto: PrivatePlanInitializeFromSelectionOutput) {
            self.success.lock().unwrap().push(dto.id);
        }
        fn on_failure(&mut self, failure: PrivatePlanInitializeFromSelectionFailure) {
            self.failures.lock().unwrap().push(failure);
        }
    }

    struct StubExistingGateway {
        existing: Option<CultivationPlanEntity>,
    }
    impl PrivatePlanExistingPlanGateway for StubExistingGateway {
        fn find_existing(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CultivationPlanEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.clone())
        }
    }

    struct StubFarmGateway {
        farm: Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>,
    }
    impl PrivatePlanFarmResolveGateway for StubFarmGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.farm {
                Ok(f) => Ok(f.clone()),
                Err(e) => Err(Box::new(RecordNotFoundError) as _),
            }
        }
    }

    struct StubCropGateway {
        crops: Vec<CropEntity>,
    }
    impl PrivatePlanCropListGateway for StubCropGateway {
        fn list_by_ids(
            &self,
            _: &[i64],
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.crops.clone())
        }
    }

    struct StubFieldGateway {
        total_area: f64,
    }
    impl FieldGateway for StubFieldGateway {
        fn get_total_area_by_farm_id(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.total_area)
        }
        fn farm_fields_list(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FarmFieldsList, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn field_with_farm(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FieldWithFarm, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create(
            &self,
            _: &crate::field::dtos::FieldCreateInput,
            _: i64,
            _: &crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
                crate::shared::policies::farm_policy::FarmRecordAccessPolicy,
            >,
        ) -> Result<crate::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update(
            &self,
            _: i64,
            _: &crate::field::dtos::FieldUpdateInput,
        ) -> Result<crate::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct StubInitializer {
        result: CultivationPlanInitializeResult,
    }
    impl PrivatePlanInitializeCallablePort for StubInitializer {
        fn call(
            &self,
            _: &CultivationPlanInitFarm,
            _: f64,
            _: &[CultivationPlanInitCrop],
            _: i64,
            _: &str,
            _: &str,
            _: Date,
            _: Date,
        ) -> Result<CultivationPlanInitializeResult, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.result.clone())
        }
    }

    struct StubSessionGen;
    impl PrivatePlanSessionIdGeneratorPort for StubSessionGen {
        fn generate(&self) -> String {
            "sessionhex".into()
        }
    }

    struct SpyJobChain {
        enqueued: Arc<Mutex<Vec<i64>>>,
        fail: bool,
    }
    impl PrivatePlanOptimizationJobChainGateway for SpyJobChain {
        fn enqueue_after_create(
            &self,
            plan_id: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            if self.fail {
                return Err("queue down".into());
            }
            self.enqueued.lock().unwrap().push(plan_id);
            Ok(())
        }
    }

    fn user(id: i64) -> User {
        User::new(id, false)
    }

    fn owned_farm(user_id: i64) -> FarmEntity {
        FarmEntity {
            id: 1,
            name: "F".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
            region: Some("jp".into()),
            user_id: Some(user_id),
            is_reference: false,
            created_at: None,
            updated_at: None,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    fn owned_crop(user_id: i64) -> CropEntity {
        CropEntity {
            id: 10,
            user_id: Some(user_id),
            name: "C".into(),
            variety: Some("V".into()),
            is_reference: false,
            area_per_unit: Some(1.0),
            revenue_per_area: Some(1.0),
            region: Some("jp".into()),
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    fn plan_entity(id: i64, user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id,
            farm_id: 1,
            user_id,
            total_area: 1.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: Some("P".into()),
            planning_start_date: Some("2026-01-01".into()),
            planning_end_date: Some("2027-12-31".into()),
            status: Some("draft".into()),
            session_id: Some("sessionhex".into()),
            display_name: Some("P".into()),
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 1,
            cultivation_plan_fields_count: 1,
            created_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn on_failure_unprocessable_when_crop_ids_empty() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::new(Mutex::new(Vec::new())),
            fail: false,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 10.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![],
            user: user(1),
            plan_name: None,
        };
        interactor.call(&input).unwrap();

        let f = failures.lock().unwrap();
        assert_eq!(f.len(), 1);
        assert_eq!(
            f[0].http_status,
            PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY
        );
        assert_eq!(f[0].message, "plans.errors.select_crop");
        assert!(success.lock().unwrap().is_empty());
    }

    #[test]
    fn on_success_enqueues_jobs_and_returns_id() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let enqueued = Arc::new(Mutex::new(Vec::new()));
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::clone(&enqueued),
            fail: false,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 100.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![10],
            user: user(1),
            plan_name: Some("P".into()),
        };
        interactor.call(&input).unwrap();

        assert_eq!(*success.lock().unwrap(), vec![42]);
        assert_eq!(*enqueued.lock().unwrap(), vec![42]);
        assert!(failures.lock().unwrap().is_empty());
    }

    #[test]
    fn enqueue_after_create_error_propagates() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::new(Mutex::new(Vec::new())),
            fail: true,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 10.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![10],
            user: user(1),
            plan_name: None,
        };
        let err = interactor.call(&input).unwrap_err();
        assert!(err.to_string().contains("queue down"));
        assert!(success.lock().unwrap().is_empty());
    }
}
