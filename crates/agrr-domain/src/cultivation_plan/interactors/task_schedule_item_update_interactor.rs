//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleItemUpdateInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::calculators::amount_unit_conversion_calculator::AmountUnitConversionCalculator;
use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::policies::task_schedule_item_update_policy;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};

pub struct TaskScheduleItemUpdateInteractor<'a, O, P, G, C> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    clock: &'a C,
    amount_unit_conversion_calculator: AmountUnitConversionCalculator,
}

impl<'a, O, P, G, C> TaskScheduleItemUpdateInteractor<'a, O, P, G, C>
where
    O: TaskScheduleItemMutationOutputPort,
    P: CultivationPlanGateway,
    G: TaskScheduleItemMutationGateway,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            clock,
            amount_unit_conversion_calculator: AmountUnitConversionCalculator,
        }
    }

    fn attrs_to_seed(attrs: &AttrMap) -> BTreeMap<String, String> {
        attrs
            .iter()
            .filter_map(|(k, v)| {
                let s = match v {
                    AttrValue::Str(s) => s.clone(),
                    AttrValue::Int(i) => i.to_string(),
                    AttrValue::Bool(b) => b.to_string(),
                    AttrValue::Null => return None,
                };
                Some((k.clone(), s))
            })
            .collect()
    }

    fn string_map_to_attr_map(map: BTreeMap<String, String>) -> AttrMap {
        attr_map_from_pairs(
            map.into_iter()
                .map(|(k, v)| (k, AttrValue::Str(v))),
        )
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
        attributes: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let amount_snapshot = self.gateway.find_item_amount_snapshot(plan_id, item_id)?;
        let seed = Self::attrs_to_seed(&attributes);
        let update_attrs = task_schedule_item_update_policy::build_update_attributes(
            &seed,
            &amount_snapshot,
            &self.amount_unit_conversion_calculator,
            self.clock.now(),
        );
        let payload = self.gateway.update_item_for_plan(
            plan_id,
            item_id,
            Self::string_map_to_attr_map(update_attrs),
        )?;
        self.output_port.on_success(payload);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
        attributes: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, item_id, attributes) {
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
