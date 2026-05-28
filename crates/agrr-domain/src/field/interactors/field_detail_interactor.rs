//! Ruby: `Domain::Field::Interactors::FieldDetailInteractor`

use crate::field::dtos::{FieldDetailFailure, FieldDetailInput};
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{DetailFailure, FieldDetailOutputPort};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Interactors::FieldDetailInteractor`
pub struct FieldDetailInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldDetailInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldDetailOutputPort,
    L: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(&mut self, input: FieldDetailInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self.gateway.field_with_farm(input.field_id) {
            Ok(result) => {
                if let Err(policy) = assert_owned(&user, &result.farm) {
                    self.output_port.on_failure(DetailFailure::FieldDetail(
                        failure_dto(policy.to_string(), &input),
                    ));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &result.farm)
                {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        policy.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                self.output_port.on_success(result);
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        policy.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        err.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}

fn failure_dto(message: String, input: &FieldDetailInput) -> FieldDetailFailure {
    FieldDetailFailure::new(message, input.farm_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::entities::FieldEntity;
    use crate::field::results::{FarmRecord, FieldWithFarm};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    enum FieldWithFarmBehavior {
        Return(FieldWithFarm),
        NotFound,
    }

    struct StubGateway {
        behavior: FieldWithFarmBehavior,
    }

    impl FieldGateway for StubGateway {
        fn get_total_area_by_farm_id(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0.0)
        }

        fn farm_fields_list(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FarmFieldsList, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }

        fn field_with_farm(
            &self,
            _: i64,
        ) -> Result<FieldWithFarm, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                FieldWithFarmBehavior::Return(v) => Ok(v.clone()),
                FieldWithFarmBehavior::NotFound => Err(Box::new(RecordNotFoundError)),
            }
        }

        fn create(
            &self,
            _: &crate::field::dtos::FieldCreateInput,
            _: i64,
            _: &crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
                crate::shared::policies::farm_policy::FarmRecordAccessPolicy,
            >,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: &crate::field::dtos::FieldUpdateInput,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<FieldWithFarm>,
        failure: Option<DetailFailure>,
    }

    impl FieldDetailOutputPort for SpyOutput {
        fn on_success(&mut self, result: FieldWithFarm) {
            self.success = Some(result);
        }

        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "call passes FieldWithFarm to output port on success"
    #[test]
    fn call_passes_field_with_farm_on_success() {
        let farm = FarmRecord {
            id: 1,
            name: "F".into(),
            user_id: Some(20),
            is_reference: false,
            latitude: None,
            longitude: None,
            region: None,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        };
        let field = FieldEntity {
            id: 2,
            farm_id: 1,
            user_id: Some(20),
            name: "North".into(),
            description: None,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
            area: None,
            daily_fixed_cost: None,
            region: None,
        };
        let result = FieldWithFarm::new(farm.clone(), field.clone());
        let gateway = StubGateway {
            behavior: FieldWithFarmBehavior::Return(result),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(20, false));
        let mut interactor = FieldDetailInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(FieldDetailInput::new(5)).unwrap();
        let received = output.success.unwrap();
        assert_eq!(received.farm, farm);
        assert_eq!(received.field, field);
    }

    // Ruby: test "call forwards RecordNotFound to on_failure as FieldDetailFailure with farm_id"
    #[test]
    fn call_forwards_record_not_found_as_field_detail_failure() {
        let gateway = StubGateway {
            behavior: FieldWithFarmBehavior::NotFound,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(20, false));
        let mut interactor = FieldDetailInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor
            .call(FieldDetailInput::with_farm_id(5, 3))
            .unwrap();
        match output.failure.unwrap() {
            DetailFailure::FieldDetail(f) => {
                assert_eq!(f.farm_id, Some(3));
            }
            other => panic!("unexpected: {other:?}"),
        }
    }
}
