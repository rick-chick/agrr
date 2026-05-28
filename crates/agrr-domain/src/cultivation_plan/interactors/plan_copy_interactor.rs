//! Ruby: `Domain::CultivationPlan::Interactors::PlanCopyInteractor`

use std::collections::HashMap;

use crate::cultivation_plan::calculators::planning_date_calculator::calculate_planning_dates_for_year;
use crate::cultivation_plan::dtos::{PlanCopyCreateAttrs, PlanCopyInput};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::gateways::PlanCopyGateway;
use crate::shared::ports::LoggerPort;

pub struct PlanCopyInteractor<'a, G, L> {
    plan_copy_gateway: &'a G,
    logger: &'a L,
}

impl<'a, G, L> PlanCopyInteractor<'a, G, L>
where
    G: PlanCopyGateway,
    L: LoggerPort,
{
    pub fn new(plan_copy_gateway: &'a G, logger: &'a L) -> Self {
        Self {
            plan_copy_gateway,
            logger,
        }
    }

    pub fn call(
        &self,
        input: PlanCopyInput,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        let source_plan = self
            .plan_copy_gateway
            .find_plan(input.source_cultivation_plan_id)?;
        let planning_dates = calculate_planning_dates_for_year(input.new_year);

        let create_attrs = PlanCopyCreateAttrs {
            farm_id: source_plan.farm_id,
            user_id: input.user_id,
            total_area: source_plan.total_area,
            plan_type: "private".into(),
            plan_year: input.new_year,
            plan_name: source_plan.plan_name.clone(),
            planning_start_date: planning_dates.start_date,
            planning_end_date: planning_dates.end_date,
            status: "pending".into(),
            session_id: input.session_id.clone(),
        };

        let new_plan = self.plan_copy_gateway.create_plan(&create_attrs)?;
        self.logger.info(&format!(
            "✅ Created new plan #{} (year: {})",
            new_plan.id, input.new_year
        ));

        let copied_attachments = self.plan_copy_gateway.copy_attachments(
            input.source_cultivation_plan_id,
            new_plan.id,
        )?;
        self.logger
            .info(&format!("✅ Copied {copied_attachments} attachments"));

        let source_fields = self
            .plan_copy_gateway
            .list_fields(input.source_cultivation_plan_id)?;
        let mut new_fields = Vec::new();
        for source_field in &source_fields {
            let created = self.plan_copy_gateway.create_field(
                new_plan.id,
                &source_field.name,
                source_field.area,
                source_field.daily_fixed_cost,
                source_field.description.as_deref(),
            )?;
            new_fields.push(created);
        }
        self.logger
            .info(&format!("✅ Copied {} fields", source_fields.len()));

        let source_crops = self
            .plan_copy_gateway
            .list_crops(input.source_cultivation_plan_id)?;
        let mut new_crops = Vec::new();
        for source_crop in &source_crops {
            let created = self.plan_copy_gateway.create_crop(
                new_plan.id,
                source_crop.crop_id,
                &source_crop.name,
                source_crop.variety.as_deref(),
                source_crop.area_per_unit,
                source_crop.revenue_per_area,
            )?;
            new_crops.push(created);
        }
        self.logger
            .info(&format!("✅ Copied {} crops", source_crops.len()));

        let mut field_mapping: HashMap<i64, i64> = HashMap::new();
        for (index, source_field) in source_fields.iter().enumerate() {
            field_mapping.insert(source_field.id, new_fields[index].id);
        }

        let mut crop_mapping: HashMap<i64, i64> = HashMap::new();
        for (index, source_crop) in source_crops.iter().enumerate() {
            crop_mapping.insert(source_crop.id, new_crops[index].id);
        }

        let source_field_cultivations = self
            .plan_copy_gateway
            .list_field_cultivations(input.source_cultivation_plan_id)?;
        for source_fc in &source_field_cultivations {
            let field_id = field_mapping
                .get(&source_fc.cultivation_plan_field_id)
                .copied()
                .expect("field mapping");
            let crop_id = crop_mapping
                .get(&source_fc.cultivation_plan_crop_id)
                .copied()
                .expect("crop mapping");
            self.plan_copy_gateway.create_field_cultivation(
                new_plan.id,
                field_id,
                crop_id,
                source_fc.area,
                &source_fc.status,
            )?;
        }

        self.logger.info(&format!(
            "✅ Copied {} field cultivations",
            source_field_cultivations.len()
        ));
        self.logger.info(&format!(
            "✅ Plan copy completed: {} -> {}",
            input.source_cultivation_plan_id, new_plan.id
        ));

        Ok(new_plan)
    }
}
