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
mod interactors_crop_ai_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_ai_create_interactor_test.rs"));
}
