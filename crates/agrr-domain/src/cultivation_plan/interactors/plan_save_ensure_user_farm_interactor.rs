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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{PlanSaveReferenceFarmSnapshot, PlanSaveUserFarmSnapshot};
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        fixed_clock_utc_2026_05_25_12_34_56, CapturingLogger, FakeTranslator,
    };
    use serde_json::Value;

    struct MockGateway {
        reference: Option<PlanSaveReferenceFarmSnapshot>,
        existing: Option<PlanSaveUserFarmSnapshot>,
        count: i64,
        created: Option<PlanSaveUserFarmSnapshot>,
    }

    impl PlanSaveFarmGateway for MockGateway {
        fn find_reference_farm(
            &self,
            farm_id: Option<i64>,
        ) -> Result<Option<PlanSaveReferenceFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            assert_eq!(farm_id, Some(10));
            Ok(self.reference.clone())
        }

        fn find_user_farm_by_source(
            &self,
            _user_id: i64,
            _source_farm_id: i64,
        ) -> Result<Option<PlanSaveUserFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.clone())
        }

        fn count_non_reference_farms(
            &self,
            _user_id: i64,
        ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.count)
        }

        fn create_user_farm_from_reference(
            &self,
            _user_id: i64,
            _reference_farm_id: i64,
            _copy_name_suffix: &str,
        ) -> Result<PlanSaveUserFarmSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.created.clone().unwrap())
        }

        fn find_owned_farm_record(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(None)
        }

        fn find_owned_private_plan_record(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(None)
        }
    }

    fn reference_farm() -> PlanSaveReferenceFarmSnapshot {
        PlanSaveReferenceFarmSnapshot {
            id: 10,
            name: Some("参照農場".into()),
            latitude: Some(35.0),
            longitude: Some(135.0),
            region: Some("kanto".into()),
            weather_location_id: Some(3),
        }
    }

    #[test]
    fn reuses_existing_user_farm_linked_to_reference() {
        let gateway = MockGateway {
            reference: Some(reference_farm()),
            existing: Some(PlanSaveUserFarmSnapshot {
                id: 77,
                name: Some("参照農場 (既存)".into()),
                region: Some("kanto".into()),
            }),
            count: 0,
            created: None,
        };
        let clock = fixed_clock_utc_2026_05_25_12_34_56();
        let logger = CapturingLogger::new();
        let interactor =
            PlanSaveEnsureUserFarmInteractor::new(&gateway, &logger, &FakeTranslator, &clock);
        let out = interactor
            .call(PlanSaveEnsureUserFarmInput {
                user_id: 1,
                reference_farm_id: 10,
            })
            .unwrap();
        assert_eq!(out.farm_id, 77);
        assert!(out.farm_reused);
        assert_eq!(out.farm_region.as_deref(), Some("kanto"));
    }

    #[test]
    fn creates_user_farm_from_reference_when_none_exists() {
        let gateway = MockGateway {
            reference: Some(reference_farm()),
            existing: None,
            count: 2,
            created: Some(PlanSaveUserFarmSnapshot {
                id: 88,
                name: Some("参照農場 (コピー 20260525_123456)".into()),
                region: Some("kanto".into()),
            }),
        };
        let clock = fixed_clock_utc_2026_05_25_12_34_56();
        let logger = CapturingLogger::new();
        let interactor =
            PlanSaveEnsureUserFarmInteractor::new(&gateway, &logger, &FakeTranslator, &clock);
        let out = interactor
            .call(PlanSaveEnsureUserFarmInput {
                user_id: 1,
                reference_farm_id: 10,
            })
            .unwrap();
        assert_eq!(out.farm_id, 88);
        assert!(!out.farm_reused);
    }

    #[test]
    fn raises_record_invalid_when_farm_create_limit_exceeded() {
        let gateway = MockGateway {
            reference: Some(reference_farm()),
            existing: None,
            count: 4,
            created: None,
        };
        let clock = fixed_clock_utc_2026_05_25_12_34_56();
        let err = PlanSaveEnsureUserFarmInteractor::new(
            &gateway,
            &CapturingLogger::new(),
            &FakeTranslator,
            &clock,
        )
        .call(PlanSaveEnsureUserFarmInput {
            user_id: 1,
            reference_farm_id: 10,
        })
        .unwrap_err();
        assert!(err.downcast_ref::<RecordInvalidError>().is_some());
    }

    #[test]
    fn raises_record_not_found_when_reference_farm_is_missing() {
        let gateway = MockGateway {
            reference: None,
            existing: None,
            count: 0,
            created: None,
        };
        let clock = fixed_clock_utc_2026_05_25_12_34_56();
        let err = PlanSaveEnsureUserFarmInteractor::new(
            &gateway,
            &CapturingLogger::new(),
            &FakeTranslator,
            &clock,
        )
        .call(PlanSaveEnsureUserFarmInput {
            user_id: 1,
            reference_farm_id: 10,
        })
        .unwrap_err();
        let not_found = err.downcast_ref::<PlanSaveRecordNotFoundError>().unwrap();
        assert_eq!(
            not_found.0,
            "services.plan_save_service.errors.farm_not_found|{:farm_id=>10}"
        );
    }
}
