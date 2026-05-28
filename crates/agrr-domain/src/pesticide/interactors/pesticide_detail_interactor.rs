//! Ruby: `Domain::Pesticide::Interactors::PesticideDetailInteractor`

use crate::pesticide::dtos::PesticideDetailOutput;
use crate::pesticide::gateways::PesticideGateway;
use crate::pesticide::ports::{DetailFailure, PesticideDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;

pub struct PesticideDetailInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> PesticideDetailInteractor<'a, G, O, U>
where
    G: PesticideGateway,
    O: PesticideDetailOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a U,
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
        pesticide_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pesticide_policy::record_access_filter(user);

        let dto = match self.gateway.find_pesticide_show_detail(pesticide_id) {
            Ok(d) => d,
            Err(err) => {
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &dto.pesticide)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port.on_success(PesticideDetailOutput::new(
            dto.pesticide,
            dto.crop_name,
            dto.pest_name,
            dto.usage_constraint_snapshot,
            dto.application_detail_snapshot,
        ));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pesticide::dtos::{
        PesticideApplicationDetailSnapshot, PesticideUsageConstraintSnapshot,
    };
    use crate::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use crate::pesticide::gateways::PesticideShowDetailGatewayDto;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct DetailGateway {
        dto: PesticideShowDetailGatewayDto,
    }

    impl PesticideGateway for DetailGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_pesticide_show_detail(
            &self,
            _: i64,
        ) -> Result<PesticideShowDetailGatewayDto, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.dto.clone())
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn crate::shared::ports::TranslatorPort,
        ) -> Result<
            crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn list_by_crop_id_for_filter(
            &self,
            _: i64,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<PesticideDetailOutput>,
        failure: Option<DetailFailure>,
    }

    impl PesticideDetailOutputPort for SpyOutput {
        fn on_success(&mut self, dto: PesticideDetailOutput) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_pesticide(user_id: Option<i64>, is_reference: bool) -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id: 3,
            user_id,
            name: "P".into(),
            active_ingredient: None,
            description: None,
            crop_id: None,
            pest_id: None,
            region: None,
            is_reference,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid")
    }

    fn detail_gateway(pesticide: PesticideEntity) -> DetailGateway {
        DetailGateway {
            dto: PesticideShowDetailGatewayDto {
                pesticide,
                crop_name: Some("トマト".into()),
                pest_name: Some("アブラムシ".into()),
                usage_constraint_snapshot: Some(PesticideUsageConstraintSnapshot {
                    min_temperature: None,
                    max_temperature: None,
                    max_wind_speed_m_s: None,
                    max_application_count: None,
                    harvest_interval_days: None,
                    other_constraints: None,
                }),
                application_detail_snapshot: Some(PesticideApplicationDetailSnapshot {
                    dilution_ratio: None,
                    amount_per_m2: None,
                    amount_unit: None,
                    application_method: None,
                }),
            },
        }
    }

    // Ruby: test "calls on_success with detail dto when view is allowed"
    #[test]
    fn calls_on_success_with_detail_dto_when_view_is_allowed() {
        let pesticide = sample_pesticide(Some(10), false);
        let gateway = detail_gateway(pesticide.clone());
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            PesticideDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(3).expect("handled");
        let received = output.success.expect("success");
        assert_eq!(received.pesticide, pesticide);
        assert_eq!(received.crop_name.as_deref(), Some("トマト"));
        assert_eq!(received.pest_name.as_deref(), Some("アブラムシ"));
        assert!(received.usage_constraint_snapshot.is_some());
        assert!(received.application_detail_snapshot.is_some());
    }

    // Ruby: test "calls on_failure with policy exception when reference pesticide is not visible"
    #[test]
    fn calls_on_failure_when_reference_pesticide_not_visible() {
        let pesticide = sample_pesticide(None, true);
        let gateway = detail_gateway(pesticide);
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            PesticideDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(3).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "calls on_failure with policy exception when other user pesticide"
    #[test]
    fn calls_on_failure_when_other_user_pesticide() {
        let pesticide = sample_pesticide(Some(99), false);
        let gateway = detail_gateway(pesticide);
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            PesticideDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(3).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
