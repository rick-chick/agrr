//! Ruby: `Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor`

use crate::cultivation_plan::dtos::CultivationPlanDestroyOutput;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::policies::private_cultivation_plan_access_policy;
use crate::cultivation_plan::ports::CultivationPlanDestroyOutputPort;
use crate::deletion_undo::exceptions::DeletionUndoError;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct CultivationPlanDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CultivationPlanDestroyInteractor<'a, G, O, U, T>
where
    G: CultivationPlanGateway,
    O: CultivationPlanDestroyOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        let plan = match self.gateway.find_by_id(plan_id) {
            Ok(plan) => plan,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let Err(PolicyPermissionDenied) =
            private_cultivation_plan_access_policy::assert_private_owned(&user, &plan)
        {
            self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
            return Ok(());
        }

        let display_name = self
            .gateway
            .private_owned_plan_display_name(&user, plan_id)?;
        let toast_message = self
            .translator
            .t_with_name("plans.undo.toast", &display_name, &opts);

        match self.gateway.delete(plan_id, &user, &toast_message) {
            Ok(undo) => {
                self.output_port
                    .on_success(CultivationPlanDestroyOutput::new(undo));
                Ok(())
            }
            Err(err) if err.downcast_ref::<AssociationInUseError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.delete_failed", &opts));
                Ok(())
            }
            Err(err) if err.downcast_ref::<DeletionUndoError>().is_some() => {
                let e = err.downcast_ref::<DeletionUndoError>().unwrap();
                let message = self.translator.t_with_message(
                    "plans.errors.delete_error",
                    &e.0,
                    &opts,
                );
                self.handle_failure(message);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                let message = invalid
                    .detail_message()
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| invalid.to_string());
                self.handle_failure(message);
                Ok(())
            }
            Err(err) => Err(err),
        }
    }

    fn handle_failure(&mut self, message: String) {
        self.output_port.on_failure(Error::new(message));
    }
}

trait DestroyTranslatorExt {
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String;
    fn t_with_message(&self, key: &str, message: &str, opts: &TranslateOptions) -> String;
}

impl<T: TranslatorPort> DestroyTranslatorExt for T {
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("name".into(), name.to_string());
        self.t(key, &o)
    }

    fn t_with_message(&self, key: &str, message: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("message".into(), message.to_string());
        self.t(key, &o)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
    use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
    use crate::deletion_undo::exceptions::DeletionUndoError;
    use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError};
    use crate::shared::user::User;
    use serde_json::json;
    use std::sync::{Arc, Mutex};

    struct FakeTranslator;
    impl TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, options: &TranslateOptions) -> String {
            if key == "plans.undo.toast" {
                let name = options.get("name").map(String::as_str).unwrap_or("");
                return format!("plans.undo.toast:{name}");
            }
            if key == "plans.errors.delete_error" {
                let message = options.get("message").map(String::as_str).unwrap_or("");
                return format!("plans.errors.delete_error:{message}");
            }
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct StubUserLookup {
        user: User,
    }
    impl UserLookupGateway for StubUserLookup {
        fn find(&self, _: i64) -> User {
            self.user.clone()
        }
    }

    enum DeleteOutcome {
        Ok(serde_json::Value),
        ErrAssociationInUse,
        ErrDeletionUndo(String),
    }

    struct StubGateway {
        plan: Option<CultivationPlanEntity>,
        display_name: String,
        delete_outcome: DeleteOutcome,
    }

    impl CultivationPlanGateway for StubGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.plan
                .clone()
                .ok_or_else(|| Box::new(RecordNotFoundError) as _)
        }

        fn create(
            &self,
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: std::collections::HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            block()
        }

        fn private_owned_plan_display_name(
            &self,
            _: &User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.display_name.clone())
        }

        fn delete(
            &self,
            _: i64,
            _: &User,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            match &self.delete_outcome {
                DeleteOutcome::Ok(v) => Ok(v.clone()),
                DeleteOutcome::ErrAssociationInUse => Err(Box::new(AssociationInUseError)),
                DeleteOutcome::ErrDeletionUndo(msg) => {
                    Err(Box::new(DeletionUndoError(msg.clone())))
                }
            }
        }
    }

    struct SpyOutput {
        success: Arc<Mutex<Option<CultivationPlanDestroyOutput>>>,
        failure: Arc<Mutex<Option<Error>>>,
    }

    impl CultivationPlanDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, dto: CultivationPlanDestroyOutput) {
            *self.success.lock().unwrap() = Some(dto);
        }
        fn on_failure(&mut self, error: Error) {
            *self.failure.lock().unwrap() = Some(error);
        }
    }

    fn private_plan(id: i64, user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id,
            farm_id: 1,
            user_id,
            total_area: 0.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: None,
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "calls on_success when deletion schedules undo"
    #[test]
    fn calls_on_success_when_deletion_schedules_undo() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let gateway = StubGateway {
            plan: Some(private_plan(1, 1)),
            display_name: "DN".into(),
            delete_outcome: DeleteOutcome::Ok(json!({"undo": true})),
        };
        let user_lookup = StubUserLookup {
            user: User::new(1, false),
        };
        let mut interactor = CultivationPlanDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &FakeTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert!(success.lock().unwrap().is_some());
        assert!(failure.lock().unwrap().is_none());
    }

    // Ruby: test "returns not found error when plan missing"
    #[test]
    fn returns_not_found_error_when_plan_missing() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let gateway = StubGateway {
            plan: None,
            display_name: String::new(),
            delete_outcome: DeleteOutcome::Ok(json!(null)),
        };
        let user_lookup = StubUserLookup {
            user: User::new(1, false),
        };
        let mut interactor = CultivationPlanDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &FakeTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert!(success.lock().unwrap().is_none());
        assert_eq!(
            failure.lock().unwrap().as_ref().map(|e| e.message.as_str()),
            Some("plans.errors.not_found")
        );
    }

    // Ruby: test "returns delete failed error when restrictions prevent deletion"
    #[test]
    fn returns_delete_failed_error_when_restrictions_prevent_deletion() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let gateway = StubGateway {
            plan: Some(private_plan(1, 1)),
            display_name: "N".into(),
            delete_outcome: DeleteOutcome::ErrAssociationInUse,
        };
        let user_lookup = StubUserLookup {
            user: User::new(1, false),
        };
        let mut interactor = CultivationPlanDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &FakeTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert_eq!(
            failure.lock().unwrap().as_ref().map(|e| e.message.as_str()),
            Some("plans.errors.delete_failed")
        );
    }

    // Ruby: test "returns delete error when undo scheduling fails"
    #[test]
    fn returns_delete_error_when_undo_scheduling_fails() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        let gateway = StubGateway {
            plan: Some(private_plan(1, 1)),
            display_name: "N".into(),
            delete_outcome: DeleteOutcome::ErrDeletionUndo("Undo error".into()),
        };
        let user_lookup = StubUserLookup {
            user: User::new(1, false),
        };
        let mut interactor = CultivationPlanDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &FakeTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert_eq!(
            failure.lock().unwrap().as_ref().map(|e| e.message.as_str()),
            Some("plans.errors.delete_error:Undo error")
        );
    }

    // Ruby: test "propagates StandardError from gateway"
    #[test]
    fn propagates_standard_error_from_gateway() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failure: Arc::clone(&failure),
        };
        struct FailingNameGateway {
            inner: StubGateway,
        }
        impl CultivationPlanGateway for FailingNameGateway {
            fn find_by_id(
                &self,
                plan_id: i64,
            ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
                self.inner.find_by_id(plan_id)
            }
            fn create(
                &self,
                attrs: &CultivationPlanCreateAttrs,
            ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
                self.inner.create(attrs)
            }
            fn update(
                &self,
                plan_id: i64,
                attrs: std::collections::HashMap<String, String>,
            ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
                self.inner.update(plan_id, attrs)
            }
            fn list_by_plan_id(
                &self,
                plan_id: i64,
            ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                self.inner.list_by_plan_id(plan_id)
            }
            fn within_transaction<F, T>(
                &self,
                block: F,
            ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
            where
                F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
            {
                self.inner.within_transaction(block)
            }
            fn private_owned_plan_display_name(
                &self,
                _: &User,
                _: i64,
            ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
                Err("Unexpected error".into())
            }
            fn delete(
                &self,
                plan_id: i64,
                user: &User,
                toast: &str,
            ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
                self.inner.delete(plan_id, user, toast)
            }
        }
        let gateway = FailingNameGateway {
            inner: StubGateway {
                plan: Some(private_plan(1, 1)),
                display_name: "N".into(),
                delete_outcome: DeleteOutcome::Ok(json!(null)),
            },
        };
        let user_lookup = StubUserLookup {
            user: User::new(1, false),
        };
        let mut interactor = CultivationPlanDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &FakeTranslator,
            &user_lookup,
        );
        let err = interactor.call(1).unwrap_err();
        assert_eq!(err.to_string(), "Unexpected error");
        assert!(failure.lock().unwrap().is_none());
    }
}
