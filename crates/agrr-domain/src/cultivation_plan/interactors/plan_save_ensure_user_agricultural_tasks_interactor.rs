//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserAgriculturalTasksInteractor`

use std::collections::{BTreeMap, HashMap};

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserAgriculturalTasksInput, PlanSaveEnsureUserAgriculturalTasksOutput,
    PlanSaveUserAgriculturalTaskSnapshot, PublicPlanSaveAgriculturalTaskReferenceRow,
};
use crate::cultivation_plan::gateways::{
    PlanSaveUserAgriculturalTaskGateway, PublicPlanSaveReadGateway,
};
use crate::cultivation_plan::mappers::{
    agricultural_task_attributes_for_create, crop_task_template_attributes_for_create,
};
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserAgriculturalTasksInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_agricultural_task_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserAgriculturalTasksInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserAgriculturalTaskGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_agricultural_task_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_agricultural_task_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserAgriculturalTasksInput,
    ) -> Result<PlanSaveEnsureUserAgriculturalTasksOutput, Box<dyn std::error::Error + Send + Sync>>
    {
        if input.reference_crop_id_to_user_crop_id.is_empty() {
            return Ok(empty_output());
        }

        let reference_crop_ids: Vec<i64> = input.reference_crop_ids();
        let rows = self
            .read_gateway
            .list_agricultural_task_reference_rows(input.region.as_deref())?;

        let mut user_agricultural_task_ids = Vec::new();
        let mut skipped_agricultural_task_ids = Vec::new();
        let mut reference_agricultural_task_id_to_user_task_id = HashMap::new();

        for row in rows {
            if !row_intersects_plan_crops(&row, &reference_crop_ids) {
                continue;
            }

            if let Some(existing) = self
                .user_agricultural_task_gateway
                .find_by_user_id_and_source_agricultural_task_id(
                    input.user_id,
                    row.reference_agricultural_task_id,
                )?
            {
                self.sync_crop_task_templates(
                    &row,
                    &existing,
                    &input.reference_crop_id_to_user_crop_id,
                )?;
                skipped_agricultural_task_ids.push(existing.id);
                user_agricultural_task_ids.push(existing.id);
                reference_agricultural_task_id_to_user_task_id
                    .insert(row.reference_agricultural_task_id, existing.id);
                continue;
            }

                let created = self.create_user_agricultural_task(&input, &row)?;
            user_agricultural_task_ids.push(created.id);
            reference_agricultural_task_id_to_user_task_id
                .insert(row.reference_agricultural_task_id, created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.agricultural_task_created",
                &BTreeMap::from([(
                    "task_name".into(),
                    created.name.clone().unwrap_or_default(),
                )]),
            ));
        }

        Ok(PlanSaveEnsureUserAgriculturalTasksOutput {
            user_agricultural_task_ids,
            skipped_agricultural_task_ids,
            reference_agricultural_task_id_to_user_task_id,
        })
    }

    fn create_user_agricultural_task(
        &self,
        input: &PlanSaveEnsureUserAgriculturalTasksInput,
        row: &PublicPlanSaveAgriculturalTaskReferenceRow,
    ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let attributes = attr_map_from_json(agricultural_task_attributes_for_create(
            row,
            input.region.as_deref(),
        ));
        let created = self
            .user_agricultural_task_gateway
            .create(input.user_id, attributes)?;
        self.sync_crop_task_templates(
            row,
            &created,
            &input.reference_crop_id_to_user_crop_id,
        )?;
        Ok(created)
    }

    fn sync_crop_task_templates(
        &self,
        row: &PublicPlanSaveAgriculturalTaskReferenceRow,
        user_task_snapshot: &PlanSaveUserAgriculturalTaskSnapshot,
        reference_crop_id_to_user_crop_id: &HashMap<i64, i64>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        for link_row in &row.template_links {
            let Some(user_crop_id) = reference_crop_id_to_user_crop_id.get(&link_row.reference_crop_id)
            else {
                continue;
            };
            if self
                .user_agricultural_task_gateway
                .find_crop_task_template(*user_crop_id, user_task_snapshot.id)?
                .is_some()
            {
                continue;
            }
            let attributes = attr_map_from_json(crop_task_template_attributes_for_create(
                link_row,
                row,
                user_task_snapshot.name.as_deref(),
            ));
            self.user_agricultural_task_gateway.create_crop_task_template(
                *user_crop_id,
                user_task_snapshot.id,
                attributes,
            )?;
        }
        Ok(())
    }
}

fn empty_output() -> PlanSaveEnsureUserAgriculturalTasksOutput {
    PlanSaveEnsureUserAgriculturalTasksOutput {
        user_agricultural_task_ids: vec![],
        skipped_agricultural_task_ids: vec![],
        reference_agricultural_task_id_to_user_task_id: HashMap::new(),
    }
}

fn row_intersects_plan_crops(row: &PublicPlanSaveAgriculturalTaskReferenceRow, reference_crop_ids: &[i64]) -> bool {
    row.linked_reference_crop_ids
        .iter()
        .any(|id| reference_crop_ids.contains(id))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PlanSaveCropTaskTemplateLinkSnapshot, PlanSaveUserAgriculturalTaskSnapshot,
        PublicPlanSaveCropTaskTemplateLinkRow, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };
    use crate::shared::attr::{AttrMap, AttrValue};

    struct MockRead {
        rows: Vec<PublicPlanSaveAgriculturalTaskReferenceRow>,
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
        ) -> Result<Vec<PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.rows.clone())
        }
        fn list_interaction_rule_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    struct MockUserAgTask {
        existing: Option<PlanSaveUserAgriculturalTaskSnapshot>,
        template_exists: bool,
    }

    impl PlanSaveUserAgriculturalTaskGateway for MockUserAgTask {
        fn find_by_user_id_and_source_agricultural_task_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<PlanSaveUserAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.existing.clone())
        }
        fn create(
            &self,
            _: i64,
            attrs: AttrMap,
        ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(attrs.get("name"), Some(&AttrValue::from("作業A")));
            Ok(PlanSaveUserAgriculturalTaskSnapshot {
                id: 88,
                name: Some("作業A".into()),
            })
        }
        fn find_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<PlanSaveCropTaskTemplateLinkSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(if self.template_exists {
                Some(PlanSaveCropTaskTemplateLinkSnapshot { id: 501 })
            } else {
                None
            })
        }
        fn create_crop_task_template(
            &self,
            _: i64,
            _: i64,
            attrs: AttrMap,
        ) -> Result<PlanSaveCropTaskTemplateLinkSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            assert_eq!(attrs.get("name"), Some(&AttrValue::from("作業A")));
            Ok(PlanSaveCropTaskTemplateLinkSnapshot { id: 501 })
        }
    }

    fn agricultural_task_row() -> PublicPlanSaveAgriculturalTaskReferenceRow {
        PublicPlanSaveAgriculturalTaskReferenceRow {
            reference_agricultural_task_id: 300,
            name: Some("作業A".into()),
            description: None,
            time_per_sqm: Some(1.5),
            weather_dependency: None,
            required_tools: None,
            skill_level: None,
            task_type: None,
            task_type_id: None,
            region: Some("jp".into()),
            linked_reference_crop_ids: vec![10],
            template_links: vec![PublicPlanSaveCropTaskTemplateLinkRow {
                reference_crop_id: 10,
                name: Some("作業A".into()),
                time_per_sqm: Some(1.5),
                description: None,
                weather_dependency: None,
                required_tools: None,
                skill_level: None,
                task_type: None,
                task_type_id: None,
                is_reference: false,
            }],
        }
    }

    fn default_input() -> PlanSaveEnsureUserAgriculturalTasksInput {
        let mut map = HashMap::new();
        map.insert(10, 101);
        PlanSaveEnsureUserAgriculturalTasksInput {
            user_id: 1,
            region: Some("jp".into()),
            reference_crop_id_to_user_crop_id: map,
        }
    }

    #[test]
    fn returns_empty_output_without_read_when_reference_crop_ids_empty() {
        let read = MockRead { rows: vec![] };
        let user_gw = MockUserAgTask {
            existing: None,
            template_exists: false,
        };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserAgriculturalTasksInteractor::new(
            &read, &user_gw, &logger, &FakeTranslator,
        )
        .call(PlanSaveEnsureUserAgriculturalTasksInput {
            user_id: 1,
            region: Some("jp".into()),
            reference_crop_id_to_user_crop_id: HashMap::new(),
        })
        .unwrap();
        assert!(out.user_agricultural_task_ids.is_empty());
    }

    #[test]
    fn creates_user_agricultural_task_and_crop_task_template_when_intersecting() {
        let read = MockRead {
            rows: vec![agricultural_task_row()],
        };
        let user_gw = MockUserAgTask {
            existing: None,
            template_exists: false,
        };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserAgriculturalTasksInteractor::new(
            &read, &user_gw, &logger, &FakeTranslator,
        )
        .call(default_input())
        .unwrap();
        assert_eq!(out.user_agricultural_task_ids, vec![88]);
        assert_eq!(out.reference_agricultural_task_id_to_user_task_id.get(&300), Some(&88));
    }
}
