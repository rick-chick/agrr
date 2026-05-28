//! Ruby: `Domain::Pesticide::Interactors::PesticideListInteractor`

use crate::pesticide::gateways::PesticideGateway;
use crate::pesticide::ports::{ListFailure, PesticideListOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::mappers::referencable_list_row_mapper::map_records;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct PesticideListInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> PesticideListInteractor<'a, G, O, U>
where
    G: PesticideGateway,
    O: PesticideListOutputPort,
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

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let filter = pesticide_policy::index_list_filter(&user);
        match self.gateway.list_index_for_filter(&filter) {
            Ok(records) => {
                let rows = map_records(&user, records);
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(ListFailure::Policy(PolicyPermissionDenied));
                    return Ok(());
                }
                if err.downcast_ref::<crate::shared::exceptions::RecordNotFoundError>().is_some()
                {
                    self.output_port.on_failure(ListFailure::Error(Error::new(
                        "Record not found".to_string(),
                    )));
                    return Ok(());
                }
                match err.downcast::<RecordInvalidError>() {
                    Ok(record_invalid) => {
                        self.output_port.on_failure(ListFailure::Error(Error::new(
                            record_invalid.to_string(),
                        )));
                        Ok(())
                    }
                    Err(err) => Err(err),
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct PolicyDeniedGateway;
    impl PesticideGateway for PolicyDeniedGateway {
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
            Err(Box::new(PolicyPermissionDenied))
        }

        fn find_pesticide_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::pesticide::gateways::PesticideShowDetailGatewayDto,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
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
        failure: Option<ListFailure>,
    }

    impl PesticideListOutputPort for SpyOutput {
        fn on_success(
            &mut self,
            _: Vec<crate::shared::dtos::ReferencableListRow<PesticideEntity>>,
        ) {
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let gateway = PolicyDeniedGateway;
        let mut output = SpyOutput { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideListInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call().expect("handled");
        assert!(matches!(
            output.failure,
            Some(ListFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
