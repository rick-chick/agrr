//! Ruby: `Domain::Crop::Interactors::CropAiCreateInteractor`

use crate::crop::dtos::{CropAiCreateFailure, HttpStatus};
use crate::crop::ports::{CropAiCreateOutputPort, CropAiQueryGateway, CropAiUpsertPersistencePort};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct CropAiCreateInteractor<'a, O, U, AQ, P, L, T> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    translator: &'a T,
    logger: &'a L,
    crop_ai_query_gateway: &'a AQ,
    persistence: &'a P,
}

impl<'a, O, U, AQ, P, L, T> CropAiCreateInteractor<'a, O, U, AQ, P, L, T>
where
    O: CropAiCreateOutputPort,
    U: UserLookupGateway,
    AQ: CropAiQueryGateway,
    P: CropAiUpsertPersistencePort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        translator: &'a T,
        logger: &'a L,
        crop_ai_query_gateway: &'a AQ,
        persistence: &'a P,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            translator,
            logger,
            crop_ai_query_gateway,
            persistence,
        }
    }

    pub fn call(
        &mut self,
        crop_name: &str,
        variety: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        if user.anonymous {
            let message = self.translator.t("auth.api.login_required", &opts);
            self.output_port.on_failure(CropAiCreateFailure::new(
                HttpStatus::Unauthorized,
                message,
            ));
            return Ok(());
        }

        let cn = crop_name.trim();
        if cn.is_empty() {
            let message = self.translator.t("api.errors.crops.name_required", &opts);
            self.output_port.on_failure(CropAiCreateFailure::new(
                HttpStatus::BadRequest,
                message,
            ));
            return Ok(());
        }

        let v = variety.map(str::trim).filter(|s| !s.is_empty());

        let crop_info = match self.crop_ai_query_gateway.fetch_crop_json(cn) {
            Ok(info) => info,
            Err(failure) => {
                self.output_port.on_failure(failure);
                return Ok(());
            }
        };

        let access_filter = crop_policy::record_access_filter(user);
        match self.persistence.upsert(&user, cn, v, crop_info, access_filter) {
            Ok(output) => {
                self.logger.info(&format!("✅ [AI Crop] Saved crop#{}", output.crop.id));
                self.output_port.on_success(output);
                Ok(())
            }
            Err(failure) => {
                self.output_port.on_failure(failure);
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::dtos::CropAiCreateOutput;
    use crate::crop::entities::CropEntity;
    use crate::shared::policies::crop_policy::CropRecordAccessPolicy;
    use crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter;
    use crate::shared::user::User;
    use serde_json::json;

    struct SpyOutput {
        success: Option<CropAiCreateOutput>,
        failure: Option<CropAiCreateFailure>,
    }

    impl CropAiCreateOutputPort for SpyOutput {
        fn on_success(&mut self, output: CropAiCreateOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: CropAiCreateFailure) {
            self.failure = Some(error);
        }
    }

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            match key {
                "auth.api.login_required" => "login required".into(),
                "api.errors.crops.name_required" => "name required".into(),
                _ => key.into(),
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct NoopQuery;
    impl CropAiQueryGateway for NoopQuery {
        fn fetch_crop_json(
            &self,
            _: &str,
        ) -> Result<serde_json::Value, CropAiCreateFailure> {
            Ok(json!({}))
        }
    }

    struct NoopPersistence;
    impl CropAiUpsertPersistencePort for NoopPersistence {
        fn upsert(
            &self,
            _: &User,
            _: &str,
            _: Option<&str>,
            _: serde_json::Value,
            _: ReferenceRecordAccessFilter<CropRecordAccessPolicy>,
        ) -> Result<CropAiCreateOutput, CropAiCreateFailure> {
            Ok(CropAiCreateOutput {
                crop: CropEntity::new(1, "Tomato", Some(1), false).unwrap(),
            })
        }
    }

    // Ruby: test "calls on_failure when user is anonymous"
    #[test]
    fn calls_on_failure_when_user_is_anonymous() {
        let mut out = SpyOutput {
            success: None,
            failure: None,
        };
        let mut i = CropAiCreateInteractor::new(
            &mut out,
            1,
            &StubLookup(User {
                id: 0,
                admin: false,
                anonymous: true,
            }),
            &StubTranslator,
            &NoopLogger,
            &NoopQuery,
            &NoopPersistence,
        );
        i.call("トマト", None).unwrap();
        assert!(out.success.is_none());
        assert_eq!(
            out.failure,
            Some(CropAiCreateFailure::new(
                HttpStatus::Unauthorized,
                "login required",
            ))
        );
    }

    // Ruby: test "calls on_failure when crop name is blank"
    #[test]
    fn calls_on_failure_when_crop_name_is_blank() {
        let mut out = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(1, false));
        let mut i = CropAiCreateInteractor::new(
            &mut out,
            1,
            &user_lookup_1,
            &StubTranslator,
            &NoopLogger,
            &NoopQuery,
            &NoopPersistence,
        );
        i.call("  ", None).unwrap();
        assert!(out.success.is_none());
        assert_eq!(
            out.failure,
            Some(CropAiCreateFailure::new(
                HttpStatus::BadRequest,
                "name required",
            ))
        );
    }
}
