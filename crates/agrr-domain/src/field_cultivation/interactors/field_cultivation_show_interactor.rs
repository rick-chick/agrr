//! Ruby: `Domain::FieldCultivation::Interactors::FieldCultivationShowInteractor`

use crate::field_cultivation::gateways::FieldCultivationGateway;
use crate::field_cultivation::interactors::plan_field_cultivation_authorization::{
    assert_field_cultivation_plan_access, assert_public_field_cultivation_plan_access,
};
use crate::field_cultivation::ports::FieldCultivationApiShowOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct FieldCultivationShowInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: Option<i64>,
    user_lookup: Option<&'a L>,
}

impl<'a, G, O, L> FieldCultivationShowInteractor<'a, G, O, L>
where
    G: FieldCultivationGateway,
    O: FieldCultivationApiShowOutputPort,
    L: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
            user_id: None,
            user_lookup: None,
        }
    }

    pub fn with_user(
        output_port: &'a mut O,
        gateway: &'a G,
        user_id: i64,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id: Some(user_id),
            user_lookup: Some(user_lookup),
        }
    }

    pub fn call(
        &mut self,
        field_cultivation_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let plan_access_snapshot = match self
            .gateway
            .find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
        {
            Ok(snapshot) => snapshot,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(Error::new(err.to_string()));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let (Some(user_id), Some(lookup)) = (self.user_id, self.user_lookup) {
            let user = lookup.find(user_id);
            if let Err(err) = assert_field_cultivation_plan_access(
                &user,
                &plan_access_snapshot,
                false,
            ) {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(Error::new("Forbidden"));
                    return Ok(());
                }
                return Err(err);
            }
        } else if let Err(err) =
            assert_public_field_cultivation_plan_access(&plan_access_snapshot)
        {
            if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                self.output_port.on_failure(Error::new("Forbidden"));
                return Ok(());
            }
            return Err(err);
        }

        let api_summary = match self
            .gateway
            .find_api_summary_by_field_cultivation_id(field_cultivation_id)
        {
            Ok(summary) => summary,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(Error::new(err.to_string()));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        self.output_port.on_success(api_summary);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_field_cultivation_show_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/interactors_field_cultivation_show_interactor_test.rs"));
}
