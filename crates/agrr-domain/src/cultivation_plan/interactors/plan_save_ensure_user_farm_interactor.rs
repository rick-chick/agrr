//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserFarmInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserFarmInput, PlanSaveEnsureUserFarmOutput,
};
use crate::cultivation_plan::errors::PlanSaveRecordNotFoundError;
use crate::cultivation_plan::gateways::PlanSaveFarmGateway;
use crate::farm::policies::FarmCreateLimitPolicy;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserFarmInteractor<'a, G, L, T, C> {
    gateway: &'a G,
    logger: &'a L,
    translator: &'a T,
    clock: &'a C,
}

impl<'a, G, L, T, C> PlanSaveEnsureUserFarmInteractor<'a, G, L, T, C>
where
    G: PlanSaveFarmGateway,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
{
    pub fn new(gateway: &'a G, logger: &'a L, translator: &'a T, clock: &'a C) -> Self {
        Self {
            gateway,
            logger,
            translator,
            clock,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserFarmInput,
    ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>> {
        let farm_id = input.reference_farm_id;
        self.logger.debug(&self.translator.t(
            "services.plan_save_service.debug.farm_id_extracted",
            &BTreeMap::from([("farm_id".into(), farm_id.to_string())]),
        ));

        let reference_farm = self
            .gateway
            .find_reference_farm(Some(farm_id))?
            .ok_or_else(|| {
                let msg = self.translator.t(
                    "services.plan_save_service.errors.farm_not_found",
                    &BTreeMap::from([("farm_id".into(), farm_id.to_string())]),
                );
                self.logger.error(&msg);
                Box::new(PlanSaveRecordNotFoundError(msg)) as Box<dyn std::error::Error + Send + Sync>
            })?;

        self.logger.debug(&self.translator.t(
            "services.plan_save_service.debug.reference_farm_found",
            &BTreeMap::from([(
                "farm_name".into(),
                reference_farm.name.clone().unwrap_or_default(),
            )]),
        ));

        if let Some(existing) = self
            .gateway
            .find_user_farm_by_source(input.user_id, reference_farm.id)?
        {
            self.logger.info(&format!(
                "♻️ [PlanSaveService] Reusing existing farm: {}",
                existing.name.as_deref().unwrap_or("")
            ));
            return Ok(PlanSaveEnsureUserFarmOutput {
                farm_id: existing.id,
                farm_reused: true,
                farm_region: existing.region,
            });
        }

        let existing_count = self.gateway.count_non_reference_farms(input.user_id)? as i32;
        if FarmCreateLimitPolicy::limit_exceeded(existing_count) {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t(
                            "activerecord.errors.models.farm.attributes.user.farm_limit_exceeded",
                            &BTreeMap::new(),
                        ),
                ),
                None,
            )));
        }

        let suffix = copy_name_suffix(self.clock.now());
        let new_farm = self.gateway.create_user_farm_from_reference(
            input.user_id,
            reference_farm.id,
            &suffix,
        )?;

        self.logger.info(&self.translator.t(
            "services.plan_save_service.messages.farm_created",
            &BTreeMap::from([(
                "farm_name".into(),
                new_farm.name.clone().unwrap_or_default(),
            )]),
        ));

        Ok(PlanSaveEnsureUserFarmOutput {
            farm_id: new_farm.id,
            farm_reused: false,
            farm_region: new_farm.region,
        })
    }
}

fn copy_name_suffix(now: time::OffsetDateTime) -> String {
    format!(
        "{:04}{:02}{:02}_{:02}{:02}{:02}",
        now.year(),
        u8::from(now.month()),
        now.day(),
        now.hour(),
        now.minute(),
        now.second(),
    )
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_farm_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_farm_interactor_test.rs"));
}
