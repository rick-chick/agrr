//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserCropsInteractor`

use std::collections::{BTreeMap, HashMap};

use crate::crop::policies::crop_create_limit_policy;
use crate::cultivation_plan::dtos::{
    PlanSaveCropStageCopyPair, PlanSaveEnsureUserCropsInput, PlanSaveEnsureUserCropsOutput,
    PublicPlanSaveCropReferenceRow,
};
use crate::cultivation_plan::gateways::{
    PlanSaveCropLimitGateway, PlanSaveUserCropGateway, PublicPlanSaveReadGateway,
};
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserCropsInteractor<'a, R, U, C, L, T> {
    read_gateway: &'a R,
    user_crop_gateway: &'a U,
    crop_gateway: &'a C,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, C, L, T> PlanSaveEnsureUserCropsInteractor<'a, R, U, C, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserCropGateway,
    C: PlanSaveCropLimitGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_crop_gateway: &'a U,
        crop_gateway: &'a C,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_crop_gateway,
            crop_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserCropsInput,
    ) -> Result<PlanSaveEnsureUserCropsOutput, Box<dyn std::error::Error + Send + Sync>> {
        if input.plan_id == 0 {
            return Err(Box::new(RecordInvalidError::new(
                Some("plan_id is required to derive crops".into()),
                None,
            )));
        }

        let reference_rows = self.read_gateway.list_crop_reference_rows(input.plan_id)?;
        let reference_crop_groups = reference_crop_groups_from_rows(&reference_rows);
        let mut user_crop_ids = Vec::new();
        let mut skipped_crop_ids = Vec::new();
        let mut reference_crop_id_to_user_crop_id = HashMap::new();
        let mut ref_cpc_id_to_user_crop_id = HashMap::new();
        let mut stage_copy_pairs = Vec::new();

        for row in reference_rows {
            if let Some(existing) = self
                .user_crop_gateway
                .find_by_user_id_and_source_crop_id(input.user_id, row.reference_crop_id)?
            {
                skipped_crop_ids.push(existing.id);
                user_crop_ids.push(existing.id);
                reference_crop_id_to_user_crop_id.insert(row.reference_crop_id, existing.id);
                ref_cpc_id_to_user_crop_id.insert(row.cultivation_plan_crop_id, existing.id);
                continue;
            }

            self.enforce_crop_create_limit(input.user_id)?;

            let attributes = crop_attributes_from_row(&row);
            let created = self
                .user_crop_gateway
                .create(input.user_id, attributes)?;

            user_crop_ids.push(created.id);
            reference_crop_id_to_user_crop_id.insert(row.reference_crop_id, created.id);
            ref_cpc_id_to_user_crop_id.insert(row.cultivation_plan_crop_id, created.id);
            stage_copy_pairs.push(PlanSaveCropStageCopyPair {
                reference_crop_id: row.reference_crop_id,
                new_crop_id: created.id,
            });
        }

        self.logger.info(&self.translator.t(
            "services.plan_save_service.debug.user_crops_created",
            &BTreeMap::from([("count".into(), user_crop_ids.len().to_string())]),
        ));

        Ok(PlanSaveEnsureUserCropsOutput {
            user_crop_ids,
            skipped_crop_ids,
            reference_crop_id_to_user_crop_id,
            ref_cpc_id_to_user_crop_id,
            stage_copy_pairs,
            reference_crop_groups,
        })
    }

    fn enforce_crop_create_limit(
        &self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let existing_count = self
            .crop_gateway
            .count_user_owned_non_reference_crops(user_id)?;
        if crop_create_limit_policy::limit_exceeded(existing_count, false) {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t(
                            "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded",
                            &BTreeMap::new(),
                        ),
                ),
                None,
            )));
        }
        Ok(())
    }
}

fn crop_attributes_from_row(row: &PublicPlanSaveCropReferenceRow) -> crate::shared::attr::AttrMap {
    attr_map_from_pairs([
        ("name", AttrValue::from(row.name.clone().unwrap_or_default())),
        (
            "variety",
            row.variety
                .clone()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        (
            "area_per_unit",
            row.area_per_unit
                .map(|v| AttrValue::Str(v.to_string()))
                .unwrap_or(AttrValue::Null),
        ),
        (
            "revenue_per_area",
            row.revenue_per_area
                .map(|v| AttrValue::Str(v.to_string()))
                .unwrap_or(AttrValue::Null),
        ),
        (
            "groups",
            row.groups
                .clone()
                .map(|g| AttrValue::Str(serde_json::to_string(&g).unwrap_or_default()))
                .unwrap_or(AttrValue::Null),
        ),
        ("is_reference", AttrValue::Bool(false)),
        (
            "region",
            row.region
                .clone()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        ("source_crop_id", AttrValue::Int(row.reference_crop_id)),
    ])
}

fn reference_crop_groups_from_rows(rows: &[PublicPlanSaveCropReferenceRow]) -> Vec<String> {
    let mut groups = Vec::new();
    for row in rows {
        if let Some(name) = row.name.as_ref().filter(|n| !n.is_empty()) {
            groups.push(name.clone());
        }
        if let Some(gs) = &row.groups {
            groups.extend(gs.iter().cloned());
        }
    }
    groups.sort();
    groups.dedup();
    groups
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PlanSaveUserCropSnapshot, PublicPlanSaveHeaderSnapshot, PublicPlanSaveFieldDatum,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };

    struct MockRead {
        rows: Vec<PublicPlanSaveCropReferenceRow>,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(
            &self,
            _: i64,
        ) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn list_field_rows(
            &self,
            _: i64,
        ) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
        fn list_crop_reference_rows(
            &self,
            _: i64,
        ) -> Result<Vec<PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.rows.clone())
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

    struct MockUserCrop {
        existing: Option<i64>,
        created_id: i64,
    }

    impl PlanSaveUserCropGateway for MockUserCrop {
        fn find_by_user_id_and_source_crop_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<PlanSaveUserCropSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.map(|id| PlanSaveUserCropSnapshot { id }))
        }

        fn create(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PlanSaveUserCropSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(PlanSaveUserCropSnapshot {
                id: self.created_id,
            })
        }
    }

    struct MockCropLimit {
        count: i32,
    }

    impl PlanSaveCropLimitGateway for MockCropLimit {
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.count)
        }
    }

    fn reference_row() -> PublicPlanSaveCropReferenceRow {
        PublicPlanSaveCropReferenceRow {
            cultivation_plan_crop_id: 1,
            reference_crop_id: 10,
            name: Some("トマト".into()),
            variety: Some("v".into()),
            area_per_unit: Some(0.2),
            revenue_per_area: Some(1000.0),
            groups: Some(vec!["g1".into()]),
            region: Some("jp".into()),
        }
    }

    #[test]
    fn reuses_existing_user_crop_and_does_not_enqueue_stage_copy() {
        let read = MockRead {
            rows: vec![reference_row()],
        };
        let user_crop = MockUserCrop {
            existing: Some(77),
            created_id: 0,
        };
        let crop_gw = MockCropLimit { count: 0 };
        let logger = CapturingLogger::new();
        let interactor = PlanSaveEnsureUserCropsInteractor::new(
            &read, &user_crop, &crop_gw, &logger, &FakeTranslator,
        );
        let out = interactor
            .call(PlanSaveEnsureUserCropsInput {
                user_id: 1,
                plan_id: 5,
            })
            .unwrap();
        assert_eq!(out.user_crop_ids, vec![77]);
        assert_eq!(out.skipped_crop_ids, vec![77]);
        assert_eq!(out.reference_crop_id_to_user_crop_id.get(&10), Some(&77));
        assert_eq!(out.ref_cpc_id_to_user_crop_id.get(&1), Some(&77));
        assert!(out.stage_copy_pairs.is_empty());
    }

    #[test]
    fn creates_user_crop_and_returns_stage_copy_pair() {
        let read = MockRead {
            rows: vec![reference_row()],
        };
        let user_crop = MockUserCrop {
            existing: None,
            created_id: 88,
        };
        let crop_gw = MockCropLimit { count: 2 };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserCropsInteractor::new(
            &read, &user_crop, &crop_gw, &logger, &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap();
        assert_eq!(out.user_crop_ids, vec![88]);
        assert!(out.skipped_crop_ids.is_empty());
        assert_eq!(out.stage_copy_pairs.len(), 1);
        assert_eq!(out.stage_copy_pairs[0].reference_crop_id, 10);
        assert_eq!(out.stage_copy_pairs[0].new_crop_id, 88);
        let mut groups = out.reference_crop_groups;
        groups.sort();
        assert_eq!(groups, vec!["g1".to_string(), "トマト".to_string()]);
    }

    #[test]
    fn creates_user_crop_for_each_row_regardless_of_crop_region() {
        let us_row = PublicPlanSaveCropReferenceRow {
            cultivation_plan_crop_id: 2,
            reference_crop_id: 99,
            name: Some("US参照作物".into()),
            variety: Some("USV".into()),
            area_per_unit: Some(0.5),
            revenue_per_area: Some(7000.0),
            groups: Some(vec![]),
            region: Some("us".into()),
        };
        let out = PlanSaveEnsureUserCropsInteractor::new(
            &MockRead { rows: vec![us_row] },
            &MockUserCrop {
                existing: None,
                created_id: 55,
            },
            &MockCropLimit { count: 0 },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap();
        assert_eq!(out.user_crop_ids, vec![55]);
        assert_eq!(out.reference_crop_id_to_user_crop_id.get(&99), Some(&55));
    }

    #[test]
    fn raises_record_invalid_when_crop_limit_exceeded() {
        let err = PlanSaveEnsureUserCropsInteractor::new(
            &MockRead {
                rows: vec![reference_row()],
            },
            &MockUserCrop {
                existing: None,
                created_id: 0,
            },
            &MockCropLimit { count: 20 },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap_err();
        assert!(err.downcast_ref::<RecordInvalidError>().is_some());
    }
}
