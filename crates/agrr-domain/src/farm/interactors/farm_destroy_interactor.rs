//! Ruby: `Domain::Farm::Interactors::FarmDestroyInteractor`

use crate::farm::dtos::FarmDestroyOutput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::{FarmGateway, SoftDeleteWithUndoOutcome};
use crate::farm::policies::{FarmDestroyBlockedReason, FarmDestroyPolicy};
use crate::farm::ports::{DestroyFailure, FarmDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{
    AssociationInUseError, RecordInvalidError, RecordNotFoundError,
};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FarmDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FarmDestroyInteractor<'a, G, O, U, T>
where
    G: FarmGateway,
    O: FarmDestroyOutputPort,
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
        farm_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = farm_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let farm_entity = match self.gateway.find_by_id(farm_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("farms.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &farm_entity)
        {
            self.output_port.on_failure(DestroyFailure::Policy(policy));
            return Ok(());
        }

        let usage = self.gateway.find_delete_usage(farm_id)?;
        if matches!(
            FarmDestroyPolicy::blocked_reason(&usage),
            Some(FarmDestroyBlockedReason::FreeCropPlans)
        ) {
            let message = self.translator.t_with_count(
                "farms.flash.cannot_delete",
                usage.free_crop_plans_count,
                &opts,
            );
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        let toast_message = self.translator.t_with_name(
            "flash.farms.deleted",
            &farm_entity.name,
            &opts,
        );

        match self.gateway.soft_delete_with_undo(
            &user,
            farm_id,
            5000,
            &toast_message,
        ) {
            Ok(SoftDeleteWithUndoOutcome::Success { undo, farm_name }) => {
                self.output_port
                    .on_success(FarmDestroyOutput::new(undo, farm_name));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err, &opts),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
        opts: &TranslateOptions,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(DestroyFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "Record not found".to_string(),
            )));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "farms.flash.cannot_delete_in_use".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(DestroyFailure::Error(Error::new(record_invalid.to_string())));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

trait FarmDestroyTranslatorExt {
    fn t_with_count(&self, key: &str, count: i32, opts: &TranslateOptions) -> String;
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String;
}

impl<T: TranslatorPort> FarmDestroyTranslatorExt for T {
    fn t_with_count(&self, key: &str, count: i32, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("count".into(), count.to_string());
        self.t(key, &o)
    }

    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("name".into(), name.to_string());
        self.t(key, &o)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::farm::dtos::FarmDeleteUsage;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, options: &TranslateOptions) -> String {
            if key == "farms.flash.cannot_delete" {
                return format!(
                    "blocked:{}",
                    options.get("count").map(String::as_str).unwrap_or("?")
                );
            }
            if key == "flash.farms.deleted" {
                return format!(
                    "toast:{}",
                    options.get("name").map(String::as_str).unwrap_or("?")
                );
            }
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<FarmDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl FarmDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, output: FarmDestroyOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    fn farm_entity(user_id: i64, name: &str) -> FarmEntity {
        FarmEntity {
            id: 5,
            name: name.into(),
            latitude: None,
            longitude: None,
            region: None,
            user_id: Some(user_id),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    enum MockBehavior {
        Success,
        BlockedByCropPlans,
        Denied,
    }

    struct StubGateway {
        behavior: MockBehavior,
        user_id: i64,
    }

    impl FarmGateway for StubGateway {
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
            Ok(farm_entity(self.user_id, "Test Farm"))
        }
        fn update_weather_progress(
            &self,
            _: i64,
            _: AttrMap,
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
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            let count = match self.behavior {
                MockBehavior::Success => 0,
                MockBehavior::BlockedByCropPlans => 3,
                MockBehavior::Denied => 0,
            };
            Ok(FarmDeleteUsage::new(count))
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            match self.behavior {
                MockBehavior::Success => Ok(SoftDeleteWithUndoOutcome::Success {
                    undo: serde_json::json!({ "expires_at": "2026-01-01T00:05:00Z" }),
                    farm_name: "Test Farm".into(),
                }),
                _ => unimplemented!(),
            }
        }
    }

    // Ruby: test "should destroy farm successfully when no crop plans exist"
    #[test]
    fn destroys_farm_when_no_crop_plans_exist() {
        let gateway = StubGateway {
            behavior: MockBehavior::Success,
            user_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(5).unwrap();
        assert!(output.success.is_some());
        assert_eq!(output.success.as_ref().unwrap().farm_name, "Test Farm");
    }

    // Ruby: test "calls on_failure when free crop plans block delete"
    #[test]
    fn calls_on_failure_when_free_crop_plans_block_delete() {
        let gateway = StubGateway {
            behavior: MockBehavior::BlockedByCropPlans,
            user_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        match output.failure {
            Some(DestroyFailure::Error(e)) => assert_eq!(e.message, "blocked:3"),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }

    // Ruby: test "calls on_failure when policy permission denied"
    #[test]
    fn calls_on_failure_when_policy_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::Denied,
            user_id: 99,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
}

