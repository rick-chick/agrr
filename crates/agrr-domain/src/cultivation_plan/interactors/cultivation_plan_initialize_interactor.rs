//! Ruby: `Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor`

use time::Date;

use crate::cultivation_plan::calculators::fields_allocation::FieldsAllocation;
use crate::cultivation_plan::calculators::planning_date_calculator::{
    calculate_public_planning_dates, PlanningDateRange,
};
use crate::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, CultivationPlanInitCrop, CultivationPlanInitFarm,
    CultivationPlanInitializeResult, CultivationPlanPlanCropCreateAttrs,
};
use crate::cultivation_plan::gateways::{
    CultivationPlanFieldMutationGateway, CultivationPlanGateway, CultivationPlanPlanCropGateway,
};
use crate::cultivation_plan::policies::cultivation_plan_field_policy;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{ClockPort, LoggerPort};

pub struct CultivationPlanInitializeInteractor<'a, CP, PC, FM, C, L> {
    farm: CultivationPlanInitFarm,
    total_area: f64,
    crops: Vec<CultivationPlanInitCrop>,
    user_id: Option<i64>,
    session_id: Option<String>,
    plan_type: String,
    plan_year: Option<i32>,
    plan_name: Option<String>,
    planning_start_date: Option<Date>,
    planning_end_date: Option<Date>,
    cultivation_plan_gateway: &'a CP,
    plan_crop_gateway: &'a PC,
    field_mutation_gateway: &'a FM,
    clock: &'a C,
    logger: &'a L,
}

impl<'a, CP, PC, FM, C, L> CultivationPlanInitializeInteractor<'a, CP, PC, FM, C, L>
where
    CP: CultivationPlanGateway,
    PC: CultivationPlanPlanCropGateway,
    FM: CultivationPlanFieldMutationGateway,
    C: ClockPort,
    L: LoggerPort,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        farm: CultivationPlanInitFarm,
        total_area: f64,
        crops: Vec<CultivationPlanInitCrop>,
        cultivation_plan_gateway: &'a CP,
        plan_crop_gateway: &'a PC,
        field_mutation_gateway: &'a FM,
        clock: &'a C,
        logger: &'a L,
    ) -> Self {
        Self {
            farm,
            total_area,
            crops,
            user_id: None,
            session_id: None,
            plan_type: "public".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            cultivation_plan_gateway,
            plan_crop_gateway,
            field_mutation_gateway,
            clock,
            logger,
        }
    }

    pub fn with_public_planning(
        mut self,
        session_id: impl Into<String>,
        planning_start_date: Date,
        planning_end_date: Date,
    ) -> Self {
        self.user_id = None;
        self.session_id = Some(session_id.into());
        self.plan_type = "public".into();
        self.plan_year = None;
        self.plan_name = None;
        self.planning_start_date = Some(planning_start_date);
        self.planning_end_date = Some(planning_end_date);
        self
    }

    pub fn with_private_planning(
        mut self,
        user_id: i64,
        session_id: Option<String>,
        plan_type: impl Into<String>,
        plan_year: Option<i32>,
        plan_name: Option<String>,
        planning_start_date: Option<Date>,
        planning_end_date: Option<Date>,
    ) -> Self {
        self.user_id = Some(user_id);
        self.session_id = session_id;
        self.plan_type = plan_type.into();
        self.plan_year = plan_year;
        self.plan_name = plan_name;
        self.planning_start_date = planning_start_date;
        self.planning_end_date = planning_end_date;
        self
    }

    pub fn call(
        self,
    ) -> Result<CultivationPlanInitializeResult, Box<dyn std::error::Error + Send + Sync>> {
        self.logger.debug(&format!(
            "🔍 [CultivationPlanInitializeInteractor] crops count: {}",
            self.crops.len()
        ));
        for (i, crop) in self.crops.iter().enumerate() {
            self.logger.debug(&format!(
                "  - Crop {}: {} (ID: {})",
                i + 1,
                crop.name,
                crop.id
            ));
        }
        self.logger.info(&format!(
            "🚀 [CultivationPlanInitializeInteractor] Starting plan creation with farm: {} ({}), crops: {}, total_area: {}",
            self.farm.name, self.farm.id, self.crops.len(), self.total_area
        ));

        if self.total_area <= 0.0 {
            let error_msg = format!(
                "総面積は0より大きい値である必要があります (total_area: {})",
                self.total_area
            );
            self.logger.error(&format!("❌ CultivationPlan creation failed: {error_msg}"));
            return Ok(CultivationPlanInitializeResult::failure(error_msg));
        }

        match self
            .cultivation_plan_gateway
            .within_transaction(|| self.create_plan_and_relations())
        {
            Ok(plan) => {
                self.logger.info(&format!(
                    "✅ Added fields and crops to CultivationPlan #{}",
                    plan.id
                ));
                Ok(CultivationPlanInitializeResult::success(plan))
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => Err(err),
            Err(err) => {
                self.logger.error(&format!("❌ CultivationPlan creation failed: {err}"));
                Ok(CultivationPlanInitializeResult::failure(err.to_string()))
            }
        }
    }

    fn create_plan_and_relations(
        &self,
    ) -> Result<crate::cultivation_plan::entities::CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        let planning_dates = self.resolve_planning_dates();
        let plan_name = self.resolve_plan_name();

        let create_attrs = CultivationPlanCreateAttrs {
            farm_id: self.farm.id,
            user_id: self.user_id,
            total_area: self.total_area,
            plan_type: self.plan_type.clone(),
            session_id: self.session_id.clone(),
            plan_year: if self.plan_type == "private" {
                self.plan_year
            } else {
                None
            },
            plan_name: if self.plan_type == "private" {
                plan_name.clone()
            } else {
                None
            },
            planning_start_date: Some(planning_dates.start_date),
            planning_end_date: Some(planning_dates.end_date),
            status: None,
        };

        let plan_entity = self.cultivation_plan_gateway.create(&create_attrs)?;
        self.create_plan_crops(plan_entity.id)?;
        self.create_plan_fields(plan_entity.id)?;
        self.cultivation_plan_gateway.find_by_id(plan_entity.id)
    }

    fn resolve_planning_dates(&self) -> PlanningDateRange {
        if self.plan_type == "private" {
            return PlanningDateRange {
                start_date: self.planning_start_date.unwrap_or_else(|| self.clock.today()),
                end_date: self.planning_end_date.unwrap_or_else(|| self.clock.today()),
            };
        }
        if let (Some(start), Some(end)) = (self.planning_start_date, self.planning_end_date) {
            return PlanningDateRange {
                start_date: start,
                end_date: end,
            };
        }
        calculate_public_planning_dates(self.clock.today())
    }

    fn resolve_plan_name(&self) -> Option<String> {
        if let Some(name) = self.plan_name.as_ref() {
            if !name.trim().is_empty() {
                return Some(name.clone());
            }
        }
        Some(self.farm.name.clone())
    }

    fn create_plan_crops(&self, plan_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        for crop in &self.crops {
            self.plan_crop_gateway.create_for_plan(&CultivationPlanPlanCropCreateAttrs {
                plan_id,
                crop_id: crop.id,
                name: crop.name.clone(),
                variety: crop.variety.clone(),
                area_per_unit: crop.area_per_unit,
                revenue_per_area: crop.revenue_per_area,
            })?;
        }
        Ok(())
    }

    fn create_plan_fields(&self, plan_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.total_area <= 0.0 || self.crops.is_empty() {
            self.logger.warn(&format!(
                "⚠️ [FieldsAllocation] Invalid parameters detected (total_area: {}, crops: {}). Creating default field.",
                self.total_area,
                self.crops.len()
            ));
        }

        let allocations = FieldsAllocation::new(self.total_area, &self.crops).allocate();
        for (index, allocation) in allocations.iter().enumerate() {
            let area = allocation.area;
            if cultivation_plan_field_policy::invalid_field_area(area) {
                continue;
            }
            let daily_cost = area * 1.0;
            self.field_mutation_gateway.create_field(
                plan_id,
                &(index + 1).to_string(),
                area,
                Some(daily_cost),
            )?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod interactors_cultivation_plan_initialize_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_cultivation_plan_initialize_interactor_test.rs"));
}
