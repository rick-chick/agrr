//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordCreateInteractor`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::work_record_create_input::record_invalid_field;
use crate::work_record::dtos::WorkRecordCreateInput;
use crate::work_record::entities::WorkRecordEntity;
use crate::work_record::gateways::{
    TaskScheduleItemLookupGateway, WorkRecordClimateSnapshotGateway, WorkRecordCreatePersistAttrs,
    WorkRecordGateway,
};
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordCreateOutputPort;

pub struct WorkRecordCreateInteractor<'a, O, P, G, L, C, S, Cl> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    item_lookup_gateway: &'a L,
    climate_snapshot_gateway: &'a Cl,
    clock: &'a C,
    scope_gateway: &'a S,
}

impl<'a, O, P, G, L, C, S, Cl> WorkRecordCreateInteractor<'a, O, P, G, L, C, S, Cl>
where
    O: WorkRecordCreateOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordGateway,
    L: TaskScheduleItemLookupGateway,
    C: ClockPort,
    S: UserOrganizationScopeGateway,
    Cl: WorkRecordClimateSnapshotGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        item_lookup_gateway: &'a L,
        climate_snapshot_gateway: &'a Cl,
        clock: &'a C,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            item_lookup_gateway,
            climate_snapshot_gateway,
            clock,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id, &org_ids) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let input = WorkRecordCreateInput::from_params(params, self.clock)?;
        let persist_attrs = self.build_persist_attrs(plan_id, &input)?;
        let record = self.gateway.create(plan_id, persist_attrs)?;
        self.output_port.on_success(record);
        Ok(())
    }

    fn build_persist_attrs(
        &self,
        plan_id: i64,
        input: &WorkRecordCreateInput,
    ) -> Result<WorkRecordCreatePersistAttrs, RecordInvalidError> {
        let now = self.clock.now();
        let prefill = match input.task_schedule_item_id {
            Some(item_id) => {
                let snapshot = self
                    .item_lookup_gateway
                    .find_item_for_plan(plan_id, item_id)
                    .map_err(|err| {
                        if err.downcast_ref::<RecordNotFoundError>().is_some() {
                            record_invalid_field(
                                "task_schedule_item_id",
                                "activerecord.errors.models.work_record.attributes.task_schedule_item_id.not_found",
                            )
                        } else {
                            record_invalid_field("base", "lookup failed")
                        }
                    })?;
                if snapshot.cultivation_plan_id != plan_id {
                    return Err(record_invalid_field(
                        "task_schedule_item_id",
                        "activerecord.errors.models.work_record.attributes.task_schedule_item_id.wrong_plan",
                    ));
                }
                Some(snapshot)
            }
            None => None,
        };

        let name = pick_string(input.name.as_deref(), prefill.as_ref().map(|p| p.name.as_str()))
            .ok_or_else(|| {
                record_invalid_field(
                    "name",
                    "activerecord.errors.models.work_record.attributes.name.blank",
                )
            })?;
        WorkRecordEntity::validate_name(&name).map_err(|_| {
            record_invalid_field(
                "name",
                "activerecord.errors.models.work_record.attributes.name.blank",
            )
        })?;

        Ok(WorkRecordCreatePersistAttrs {
            field_cultivation_id: input
                .field_cultivation_id
                .or_else(|| prefill.as_ref().and_then(|p| p.field_cultivation_id)),
            task_schedule_item_id: input.task_schedule_item_id,
            agricultural_task_id: input
                .agricultural_task_id
                .or_else(|| prefill.as_ref().and_then(|p| p.agricultural_task_id)),
            fertilize_id: input.fertilize_id,
            pesticide_id: input.pesticide_id,
            name,
            task_type: input
                .task_type
                .clone()
                .or_else(|| prefill.as_ref().and_then(|p| p.task_type.clone())),
            actual_date: input.actual_date,
            amount: input.amount.or_else(|| prefill.as_ref().and_then(|p| p.amount)),
            amount_unit: input
                .amount_unit
                .clone()
                .or_else(|| prefill.as_ref().and_then(|p| p.amount_unit.clone())),
            time_spent_minutes: input.time_spent_minutes,
            notes: input.notes.clone(),
            gdd_at_actual: None,
            weather_snapshot: None,
            created_at: now,
            updated_at: now,
        })
        .map(|mut attrs| {
            if let Some(fc_id) = attrs.field_cultivation_id {
                if let Ok(snapshot) = self
                    .climate_snapshot_gateway
                    .lookup(fc_id, attrs.actual_date)
                {
                    attrs.gdd_at_actual = snapshot.gdd_at_actual;
                    attrs.weather_snapshot = snapshot.weather_snapshot;
                }
            }
            attrs
        })
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, params) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.output_port.on_record_invalid(
                    from_errors(ErrorsInput::ValidationErrors(
                        invalid.errors.as_ref().expect("record invalid"),
                    )),
                    &invalid.to_string(),
                );
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

fn pick_string(override_value: Option<&str>, fallback: Option<&str>) -> Option<String> {
    override_value
        .filter(|s| !s.trim().is_empty())
        .map(str::to_string)
        .or_else(|| fallback.filter(|s| !s.trim().is_empty()).map(str::to_string))
}

#[cfg(test)]
mod interactors_work_record_create_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_create_interactor_test.rs"
    ));
}
