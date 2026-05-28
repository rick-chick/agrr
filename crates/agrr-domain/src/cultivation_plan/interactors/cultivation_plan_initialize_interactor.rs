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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::CultivationPlanPlanCropCreateAttrs;
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use std::sync::{Arc, Mutex};

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            time::macros::date!(2026-03-01)
        }
        fn now(&self) -> time::OffsetDateTime {
            time::macros::datetime!(2026-03-01 0:00 UTC)
        }
    }

    struct StubPlanGateway {
        created_id: i64,
        in_txn: Arc<Mutex<bool>>,
    }
    impl CultivationPlanGateway for StubPlanGateway {
        fn find_by_id(
            &self,
            id: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CultivationPlanEntity {
                id,
                farm_id: 1,
                user_id: 0,
                total_area: 100.0,
                plan_type: "public".into(),
                plan_year: None,
                plan_name: None,
                planning_start_date: Some("2026-01-01".into()),
                planning_end_date: Some("2026-12-31".into()),
                status: Some("draft".into()),
                session_id: None,
                display_name: Some("p".into()),
                optimization_phase: None,
                optimization_phase_message: None,
                cultivation_plan_crops_count: 0,
                cultivation_plan_fields_count: 0,
                created_at: None,
                updated_at: None,
            })
        }
        fn create(
            &self,
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.find_by_id(self.created_id)
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
        ) -> Result<Vec<crate::cultivation_plan::entities::FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            *self.in_txn.lock().unwrap() = true;
            block()
        }
        fn private_owned_plan_display_name(
            &self,
            _: &crate::shared::user::User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(
            &self,
            _: i64,
            _: &crate::shared::user::User,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyPlanCropGateway {
        created: Arc<Mutex<bool>>,
    }
    impl CultivationPlanPlanCropGateway for SpyPlanCropGateway {
        fn create_for_plan(
            &self,
            _: &CultivationPlanPlanCropCreateAttrs,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            *self.created.lock().unwrap() = true;
            Ok(())
        }
        fn create(
            &self,
            _: i64,
            _: &crate::crop::dtos::AddCropCropSnapshot,
        ) -> Result<crate::cultivation_plan::dtos::CultivationPlanCropSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn delete(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyFieldMutationGateway {
        create_count: Arc<Mutex<usize>>,
    }
    impl CultivationPlanFieldMutationGateway for SpyFieldMutationGateway {
        fn count_fields(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0)
        }
        fn find_field(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn create_field(
            &self,
            _: i64,
            _: &str,
            _: f64,
            _: Option<f64>,
        ) -> Result<crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            *self.create_count.lock().unwrap() += 1;
            Ok(crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot::new(1, "1", 1.0))
        }
        fn delete_field(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
        fn refresh_total_area(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0.0)
        }
    }

    #[test]
    fn returns_failure_when_total_area_is_not_positive() {
        let plan_gateway = StubPlanGateway {
            created_id: 99,
            in_txn: Arc::new(Mutex::new(false)),
        };
        let plan_crop_gateway = SpyPlanCropGateway {
            created: Arc::new(Mutex::new(false)),
        };
        let field_gateway = SpyFieldMutationGateway {
            create_count: Arc::new(Mutex::new(0)),
        };
        let clock = FakeClock;
        let logger = FakeLogger;
        let interactor = CultivationPlanInitializeInteractor::new(
            CultivationPlanInitFarm {
                id: 1,
                name: "Farm".into(),
            },
            0.0,
            vec![CultivationPlanInitCrop {
                id: 10,
                name: "Crop".into(),
                variety: Some("V".into()),
                area_per_unit: 1.0,
                revenue_per_area: 100.0,
            }],
            &plan_gateway,
            &plan_crop_gateway,
            &field_gateway,
            &clock,
            &logger,
        );

        let result = interactor.call().unwrap();
        assert!(!result.is_success());
        assert!(result.errors[0].contains("総面積"));
    }

    #[test]
    fn creates_plan_crops_and_fields_inside_transaction_when_valid() {
        let in_txn = Arc::new(Mutex::new(false));
        let crop_created = Arc::new(Mutex::new(false));
        let field_count = Arc::new(Mutex::new(0));
        let plan_gateway = StubPlanGateway {
            created_id: 99,
            in_txn: Arc::clone(&in_txn),
        };
        let plan_crop_gateway = SpyPlanCropGateway {
            created: Arc::clone(&crop_created),
        };
        let field_gateway = SpyFieldMutationGateway {
            create_count: Arc::clone(&field_count),
        };
        let clock = FakeClock;
        let logger = FakeLogger;
        let interactor = CultivationPlanInitializeInteractor::new(
            CultivationPlanInitFarm {
                id: 1,
                name: "Farm".into(),
            },
            100.0,
            vec![CultivationPlanInitCrop {
                id: 10,
                name: "Crop".into(),
                variety: Some("V".into()),
                area_per_unit: 1.0,
                revenue_per_area: 100.0,
            }],
            &plan_gateway,
            &plan_crop_gateway,
            &field_gateway,
            &clock,
            &logger,
        );

        let result = interactor.call().unwrap();
        assert!(result.is_success());
        assert_eq!(result.cultivation_plan.unwrap().id, 99);
        assert!(*in_txn.lock().unwrap());
        assert!(*crop_created.lock().unwrap());
        assert!(*field_count.lock().unwrap() >= 1);
    }
}
