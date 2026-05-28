//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleItemCreateInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::policies::task_schedule_item_create_policy;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::validation::{from_errors, ErrorsInput};

pub struct TaskScheduleItemCreateInteractor<'a, O, P, G> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
}

impl<'a, O, P, G> TaskScheduleItemCreateInteractor<'a, O, P, G>
where
    O: TaskScheduleItemMutationOutputPort,
    P: CultivationPlanGateway,
    G: TaskScheduleItemMutationGateway,
{
    pub fn new(output_port: &'a mut O, plan_gateway: &'a P, gateway: &'a G) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
        }
    }

    fn attrs_to_params(attrs: &AttrMap) -> BTreeMap<String, Option<String>> {
        attrs
            .iter()
            .map(|(k, v)| {
                let val = match v {
                    AttrValue::Str(s) => Some(s.clone()),
                    AttrValue::Int(i) => Some(i.to_string()),
                    AttrValue::Bool(b) => Some(b.to_string()),
                    AttrValue::Null => None,
                };
                (k.clone(), val)
            })
            .collect()
    }

    fn create_attrs_to_attr_map(
        attrs: &task_schedule_item_create_policy::TaskScheduleItemCreateAttributes,
    ) -> AttrMap {
        let mut pairs = Vec::new();
        if let Some(id) = attrs.field_cultivation_id {
            pairs.push(("field_cultivation_id".to_string(), AttrValue::Int(id)));
        }
        pairs.push(("task_type".to_string(), AttrValue::Str(attrs.task_type.clone())));
        pairs.push(("name".to_string(), AttrValue::Str(attrs.name.clone())));
        if let Some(d) = &attrs.scheduled_date {
            pairs.push(("scheduled_date".to_string(), AttrValue::Str(d.clone())));
        }
        attr_map_from_pairs(pairs)
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        attributes: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let params = Self::attrs_to_params(&attributes);
        let field_cultivation_id = params
            .get("field_cultivation_id")
            .and_then(|v| v.as_deref())
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        let field_cultivation = self
            .gateway
            .find_field_cultivation_for_create(plan_id, field_cultivation_id)?;

        let template_id = params
            .get("crop_task_template_id")
            .and_then(|v| v.as_deref())
            .and_then(|s| s.parse().ok());
        let template = self
            .gateway
            .find_crop_task_template_for_mutation(template_id)?;

        let submitted_crop_id = params
            .get("cultivation_plan_crop_id")
            .and_then(|v| v.as_deref())
            .and_then(|s| s.parse().ok());

        task_schedule_item_create_policy::validate_crop_selection(
            Some(field_cultivation.cultivation_plan_crop_id),
            submitted_crop_id,
        )?;
        task_schedule_item_create_policy::validate_template(
            Some(field_cultivation.crop_id),
            template.as_ref(),
        )?;

        let create_attrs =
            task_schedule_item_create_policy::build_create_attributes(&params, template.as_ref())?;
        let gateway_attrs = Self::create_attrs_to_attr_map(&create_attrs);
        let payload = self.gateway.create(plan_id, gateway_attrs)?;
        self.output_port.on_created(payload);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        attributes: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, attributes) {
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
