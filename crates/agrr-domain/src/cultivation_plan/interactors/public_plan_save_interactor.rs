//! Ruby: `Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor`

use crate::cultivation_plan::dtos::{
    PublicPlanSaveFailure, PublicPlanSaveFromSessionOutput, PublicPlanSaveInput,
    PublicPlanSaveSessionData, PublicPlanSaveWorkspace,
};
use crate::cultivation_plan::gateways::{PublicPlanSaveReadGateway, PublicPlanSaveTxnGateway};
use crate::cultivation_plan::mappers::session_data_from_snapshots;
use crate::cultivation_plan::ports::{
    PublicPlanSaveFromSessionOutputPort, PublicPlanSavePersistencePort,
};
use crate::farm::gateways::FarmGateway;
use crate::shared::exceptions::{InvalidTaskScheduleItemError, RecordInvalidError};
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PublicPlanSaveInteractor<'a, O, TX, R, F, P, L, T> {
    output_port: &'a mut O,
    txn_gateway: &'a TX,
    read_gateway: &'a R,
    farm_gateway: &'a F,
    persistence_port: &'a P,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, O, TX, R, F, P, L, T> PublicPlanSaveInteractor<'a, O, TX, R, F, P, L, T>
where
    O: PublicPlanSaveFromSessionOutputPort,
    TX: PublicPlanSaveTxnGateway,
    R: PublicPlanSaveReadGateway,
    F: FarmGateway,
    P: PublicPlanSavePersistencePort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        txn_gateway: &'a TX,
        read_gateway: &'a R,
        farm_gateway: &'a F,
        persistence_port: &'a P,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            output_port,
            txn_gateway,
            read_gateway,
            farm_gateway,
            persistence_port,
            logger,
            translator,
        }
    }

    pub fn call(
        &mut self,
        input: &PublicPlanSaveInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !input.plan_id_present() && input.session_data.is_none() {
            self.output_port.on_failure(PublicPlanSaveFailure::new(
                PublicPlanSaveFailure::KIND_MISSING_PLAN_ID,
                None,
            ));
            return Ok(());
        }

        let session_data = match self.resolve_session_data(input) {
            Some(data) => data,
            None => {
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_PLAN_NOT_FOUND,
                    None,
                ));
                return Ok(());
            }
        };

        let workspace = PublicPlanSaveWorkspace {
            user_id: input.user_id,
            session_data,
        };

        match self.persist_workspace(&workspace) {
            Ok(output) if output.success => {
                self.output_port.on_success();
                Ok(())
            }
            Ok(output) => {
                let fallback = self
                    .translator
                    .t("public_plans.save.error", &Default::default());
                let text = output
                    .error_message
                    .filter(|m| !m.trim().is_empty())
                    .unwrap_or(fallback);
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_SAVE_FAILED,
                    Some(text),
                ));
                Ok(())
            }
            Err(err) if err.downcast_ref::<InvalidTaskScheduleItemError>().is_some() => {
                let e = err.downcast_ref::<InvalidTaskScheduleItemError>().unwrap();
                self.logger.error(
                    "❌ [PublicPlanSaveInteractor] InvalidTaskScheduleItem",
                );
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_UNEXPECTED,
                    Some(self.translator.t("public_plans.save.error", &Default::default())),
                ));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.error(&format!(
                    "❌ [PublicPlanSaveInteractor] RecordInvalid: {invalid}"
                ));
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_SAVE_FAILED,
                    Some(invalid.to_string()),
                ));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }

    fn persist_workspace(
        &self,
        workspace: &PublicPlanSaveWorkspace,
    ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>> {
        self.txn_gateway
            .within_transaction(|| self.persistence_port.execute_save(workspace))
    }

    fn resolve_session_data(
        &self,
        input: &PublicPlanSaveInput,
    ) -> Option<PublicPlanSaveSessionData> {
        if let Some(session_data) = &input.session_data {
            return Some(session_data.clone());
        }

        let plan_id = input.plan_id?;
        let header = self.read_gateway.find_header(plan_id).ok().and_then(|h| h)?;
        let farm_id = header.farm_id?;
        self.farm_gateway.find_by_id(farm_id).ok()?;
        let field_rows = self.read_gateway.list_field_rows(plan_id).ok()?;
        Some(session_data_from_snapshots(&header, &field_rows))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot, PublicPlanSaveSessionData,
    };
    use crate::farm::entities::FarmEntity;
    use crate::shared::exceptions::InvalidTaskScheduleItemError;
    use crate::shared::ports::translator_port::TranslateOptions;
    use std::sync::{Arc, Mutex};

    struct FakeTranslator;
    impl crate::shared::ports::TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FakeLogger;
    impl crate::shared::ports::LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct SpyOutput {
        success: Arc<Mutex<bool>>,
        failure: Arc<Mutex<Option<PublicPlanSaveFailure>>>,
    }
    impl PublicPlanSaveFromSessionOutputPort for SpyOutput {
        fn on_success(&mut self) {
            *self.success.lock().unwrap() = true;
        }
        fn on_failure(&mut self, failure: PublicPlanSaveFailure) {
            *self.failure.lock().unwrap() = Some(failure);
        }
    }

    struct StubTxn;
    impl PublicPlanSaveTxnGateway for StubTxn {
        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            block()
        }
    }

    struct StubRead {
        header: Option<PublicPlanSaveHeaderSnapshot>,
        fields: Vec<PublicPlanSaveFieldDatum>,
    }
    impl PublicPlanSaveReadGateway for StubRead {
        fn find_header(
            &self,
            _: i64,
        ) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.header.clone())
        }
        fn list_field_rows(
            &self,
            _: i64,
        ) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.fields.clone())
        }
        fn list_crop_reference_rows(
            &self,
            _: i64,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_pest_reference_rows(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_pesticide_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_fertilize_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn exists_fertilize_name(&self, _: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(false)
        }
        fn list_agricultural_task_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_interaction_rule_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    struct StubFarm {
        farm: Option<FarmEntity>,
    }
    impl FarmGateway for StubFarm {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.farm
                .clone()
                .ok_or_else(|| Box::new(crate::shared::exceptions::RecordNotFoundError) as _)
        }
        fn update_weather_progress(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<crate::farm::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
    }

    struct StubPersistence {
        output: Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>>,
    }
    impl PublicPlanSavePersistencePort for StubPersistence {
        fn execute_save(
            &self,
            _: &PublicPlanSaveWorkspace,
        ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>> {
            match &self.output {
                Ok(v) => Ok(v.clone()),
                Err(_) => Err(Box::new(InvalidTaskScheduleItemError) as _),
            }
        }
    }

    fn header() -> PublicPlanSaveHeaderSnapshot {
        PublicPlanSaveHeaderSnapshot::new(99, Some(7))
    }

    fn farm() -> FarmEntity {
        FarmEntity {
            id: 7,
            name: "F".into(),
            latitude: None,
            longitude: None,
            region: None,
            user_id: None,
            created_at: None,
            updated_at: None,
            is_reference: true,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    #[test]
    fn on_failure_when_plan_id_missing() {
        let success = Arc::new(Mutex::new(false));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let read = StubRead {
            header: None,
            fields: vec![],
        };
        let farm_gw = StubFarm { farm: Some(farm()) };
        let persistence = StubPersistence {
            output: Ok(PublicPlanSaveFromSessionOutput::success()),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let mut interactor = PublicPlanSaveInteractor::new(
            &mut output,
            &StubTxn,
            &read,
            &farm_gw,
            &persistence,
            &logger,
            &translator,
        );
        interactor
            .call(&PublicPlanSaveInput {
                plan_id: None,
                user_id: 42,
                session_data: None,
            })
            .unwrap();
        let f = failure.lock().unwrap().clone().unwrap();
        assert_eq!(f.kind, PublicPlanSaveFailure::KIND_MISSING_PLAN_ID);
        assert!(!*success.lock().unwrap());
    }

    #[test]
    fn on_success_when_persistence_succeeds() {
        let success = Arc::new(Mutex::new(false));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let read = StubRead {
            header: Some(header()),
            fields: vec![],
        };
        let farm_gw = StubFarm { farm: Some(farm()) };
        let persistence = StubPersistence {
            output: Ok(PublicPlanSaveFromSessionOutput::success()),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let mut interactor = PublicPlanSaveInteractor::new(
            &mut output,
            &StubTxn,
            &read,
            &farm_gw,
            &persistence,
            &logger,
            &translator,
        );
        interactor
            .call(&PublicPlanSaveInput {
                plan_id: Some(99),
                user_id: 42,
                session_data: None,
            })
            .unwrap();
        assert!(*success.lock().unwrap());
        assert!(failure.lock().unwrap().is_none());
    }
}
