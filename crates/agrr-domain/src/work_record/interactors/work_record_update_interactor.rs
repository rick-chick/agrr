//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordUpdateInteractor`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::WorkRecordUpdateInput;
use crate::work_record::gateways::{WorkRecordClimateSnapshotGateway, WorkRecordGateway};
use crate::work_record::interactors::work_record_create_interactor::resolve_climate_snapshot;
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordUpdateOutputPort;

pub struct WorkRecordUpdateInteractor<'a, O, P, G, C, S, Cl> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    climate_snapshot_gateway: &'a Cl,
    clock: &'a C,
    scope_gateway: &'a S,
}

impl<'a, O, P, G, C, S, Cl> WorkRecordUpdateInteractor<'a, O, P, G, C, S, Cl>
where
    O: WorkRecordUpdateOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordGateway,
    Cl: WorkRecordClimateSnapshotGateway,
    C: ClockPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        climate_snapshot_gateway: &'a Cl,
        clock: &'a C,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            climate_snapshot_gateway,
            clock,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id, &org_ids) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let input = WorkRecordUpdateInput::from_params(params, self.clock)?;
        let mut update_input = input;
        if update_input.actual_date.is_some() {
            let existing = self.gateway.find_for_plan(plan_id, record_id)?;
            let actual_date = update_input.actual_date.unwrap_or(existing.actual_date);
            let climate_snapshot = resolve_climate_snapshot(
                self.climate_snapshot_gateway,
                user_id,
                existing.field_cultivation_id,
                actual_date,
            );
            update_input.gdd_at_actual = climate_snapshot.gdd_at_actual;
            update_input.weather_snapshot = climate_snapshot.weather_snapshot;
        }
        let record = self
            .gateway
            .update(plan_id, record_id, &update_input, self.clock.now())?;
        self.output_port.on_success(record);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, record_id, params) {
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

#[cfg(test)]
mod interactors_work_record_update_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_update_interactor_test.rs"
    ));
}
