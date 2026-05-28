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
        if let (Some(user_id), Some(lookup)) = (self.user_id, self.user_lookup) {
            let user = lookup.find(user_id);
            if let Err(err) = assert_field_cultivation_plan_access(
                &user,
                self.gateway,
                field_cultivation_id,
                false,
            ) {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(Error::new("Forbidden"));
                    return Ok(());
                }
                return Err(err);
            }
        } else if let Err(err) =
            assert_public_field_cultivation_plan_access(self.gateway, field_cultivation_id)
        {
            if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                self.output_port.on_failure(Error::new("Forbidden"));
                return Ok(());
            }
            return Err(err);
        }

        match self.gateway.find_api_summary(field_cultivation_id) {
            Ok(dto) => {
                self.output_port.on_success(dto);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(Error::new(err.to_string()));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::{
        FieldCultivationApiSummary, FieldCultivationPlanAccessSnapshot,
    };
    use crate::field_cultivation::gateways::FieldCultivationPlanAccessGateway;
    use time::macros::date;

    struct StubGateway {
        access: FieldCultivationPlanAccessSnapshot,
        summary: Option<FieldCultivationApiSummary>,
        fail_not_found: bool,
    }

    impl FieldCultivationPlanAccessGateway for StubGateway {
        fn find_plan_access_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.access.clone())
        }
    }

    impl FieldCultivationGateway for StubGateway {
        fn find_api_summary(
            &self,
            _: i64,
        ) -> Result<FieldCultivationApiSummary, Box<dyn std::error::Error + Send + Sync>> {
            if self.fail_not_found {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.summary.clone().unwrap())
        }

        fn update_field_cultivation_schedule(
            &self,
            _: i64,
            _: &str,
            _: &str,
            _: Option<i32>,
        ) -> Result<
            crate::field_cultivation::dtos::FieldCultivationApiUpdateOutput,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    struct StubLookup;
    impl UserLookupGateway for StubLookup {
        fn find(&self, id: i64) -> crate::shared::user::User {
            crate::shared::user::User::new(id, false)
        }
    }

    struct SpyOutput {
        success: Option<FieldCultivationApiSummary>,
        failure: Option<Error>,
    }

    impl FieldCultivationApiShowOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FieldCultivationApiSummary) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    #[test]
    fn calls_on_success_when_gateway_returns_summary() {
        let summary = FieldCultivationApiSummary {
            id: 42,
            field_name: "F".into(),
            crop_name: "C".into(),
            area: 1.0,
            start_date: date!(2026 - 01 - 01),
            completion_date: date!(2026 - 01 - 02),
            cultivation_days: 2,
            estimated_cost: 3.0,
            gdd: 4.0,
            status: "completed".into(),
        };
        let gateway = StubGateway {
            access: FieldCultivationPlanAccessSnapshot::new(42, true, false, None),
            summary: Some(summary.clone()),
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor =
            FieldCultivationShowInteractor::<_, _, StubLookup>::new(&mut output, &gateway);
        interactor.call(42).unwrap();
        assert_eq!(output.success.unwrap(), summary);
    }

    #[test]
    fn forbidden_for_private_plan_non_owner() {
        let gateway = StubGateway {
            access: FieldCultivationPlanAccessSnapshot::new(7, false, true, Some(99)),
            summary: None,
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup;
        let mut interactor =
            FieldCultivationShowInteractor::with_user(&mut output, &gateway, 1, &lookup);
        interactor.call(7).unwrap();
        assert_eq!(output.failure.unwrap().message, "Forbidden");
    }
}
