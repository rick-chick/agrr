//! Ruby: `Domain::Field::Interactors::FieldUpdateInteractor`

use crate::field::dtos::FieldUpdateInput;
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{FieldUpdateOutputPort, UpdateFailure};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Interactors::FieldUpdateInteractor`
pub struct FieldUpdateInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldUpdateInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldUpdateOutputPort,
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

    pub fn call(
        &mut self,
        update_input: FieldUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self.gateway.field_with_farm(update_input.id) {
            Ok(with_farm) => {
                if let Err(policy) = assert_owned(&user, &with_farm.farm) {
                    self.output_port.on_failure(UpdateFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &with_farm.farm)
                {
                    self.output_port.on_failure(UpdateFailure::Policy(policy));
                    return Ok(());
                }
                match self.gateway.update(update_input.id, &update_input) {
                    Ok(field) => {
                        self.output_port.on_success(field);
                        Ok(())
                    }
                    Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
                }
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            output_port.on_failure(UpdateFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
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

    enum MockBehavior {
        WithFarm(FieldWithFarm),
        WithFarmOtherOwner,
        NotFound,
        UpdateReturns(FieldEntity),
    }

    struct StubGateway {
        behavior: MockBehavior,
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
                MockBehavior::WithFarm(v) => Ok(v.clone()),
                MockBehavior::WithFarmOtherOwner => Ok(FieldWithFarm::new(
                    FarmRecord {
                        id: 1,
                        name: "F".into(),
                        user_id: Some(99),
                        is_reference: false,
                        latitude: None,
                        longitude: None,
                        region: None,
                        created_at: None,
                        updated_at: None,
                    },
                    FieldEntity {
                        id: 5,
                        farm_id: 1,
                        user_id: Some(99),
                        name: "X".into(),
                        description: None,
                        created_at: None,
                        updated_at: None,
                        area: None,
                        daily_fixed_cost: None,
                        region: None,
                    },
                )),
                MockBehavior::NotFound => Err(Box::new(RecordNotFoundError)),
                MockBehavior::UpdateReturns(_) => unreachable!(),
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
            _: &FieldUpdateInput,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::UpdateReturns(f) => Ok(f.clone()),
                MockBehavior::WithFarm(_) => {
                    Ok(FieldEntity {
                        id: 5,
                        farm_id: 1,
                        user_id: Some(9),
                        name: "Updated".into(),
                        description: None,
                        created_at: Some("2026-01-01T00:00:00Z".into()),
                        updated_at: Some("2026-01-01T00:00:00Z".into()),
                        area: None,
                        daily_fixed_cost: None,
                        region: None,
                    })
                }
                _ => unimplemented!(),
            }
        }

        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<FieldEntity>,
        failure: Option<UpdateFailure>,
    }

    impl FieldUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, field: FieldEntity) {
            self.success = Some(field);
        }

        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "call passes FieldEntity to output port on success"
    #[test]
    fn call_passes_field_entity_on_success() {
        let farm = FarmRecord {
            id: 1,
            name: "F".into(),
            user_id: Some(20),
            is_reference: false,
            latitude: None,
            longitude: None,
            region: None,
            created_at: None,
            updated_at: None,
        };
        let with_farm = FieldWithFarm::new(
            farm,
            FieldEntity {
                id: 5,
                farm_id: 1,
                user_id: Some(9),
                name: "Old".into(),
                description: None,
                created_at: None,
                updated_at: None,
                area: None,
                daily_fixed_cost: None,
                region: None,
            },
        );
        let gateway = StubGateway {
            behavior: MockBehavior::WithFarm(with_farm),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut dto = FieldUpdateInput::new(5);
        dto.name = Some("Updated".into());
        let lookup = StubLookup(User::new(20, false));
        let mut interactor = FieldUpdateInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(dto).unwrap();
        assert_eq!(output.success.unwrap().name, "Updated");
    }

    // Ruby: test "call forwards RecordNotFound to on_failure as Error"
    #[test]
    fn call_forwards_record_not_found() {
        let gateway = StubGateway {
            behavior: MockBehavior::NotFound,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut dto = FieldUpdateInput::new(5);
        dto.name = Some("X".into());
        let lookup = StubLookup(User::new(20, false));
        let mut interactor = FieldUpdateInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(dto).unwrap();
        assert!(matches!(output.failure, Some(UpdateFailure::Error(_))));
    }

    // Ruby: test "call forwards policy permission denied to on_failure as exception"
    #[test]
    fn call_forwards_policy_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::WithFarmOtherOwner,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut dto = FieldUpdateInput::new(5);
        dto.name = Some("X".into());
        let lookup = StubLookup(User::new(20, false));
        let mut interactor = FieldUpdateInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(dto).unwrap();
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
