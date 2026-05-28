//! Ruby: `Domain::Farm::Interactors::FarmListInteractor`

use crate::farm::dtos::FarmListInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{FarmListOutputPort, FarmListSuccess, ListFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct FarmListInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
}

impl<'a, G, O> FarmListInteractor<'a, G, O>
where
    G: FarmGateway,
    O: FarmListOutputPort,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
        }
    }

    pub fn call(
        &mut self,
        input: Option<FarmListInput>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let input = input.unwrap_or_default();
        let result = if input.is_admin {
            match (
                self.gateway.list_user_and_reference_farms(self.user_id),
                self.gateway.list_reference_farms(),
            ) {
                (Ok(farms), Ok(reference_farms)) => FarmListSuccess {
                    farms,
                    reference_farms,
                },
                (Err(err), _) | (_, Err(err)) => {
                    return Self::handle_err(&mut self.output_port, err);
                }
            }
        } else {
            match self.gateway.list_user_owned_farms(self.user_id) {
                Ok(farms) => FarmListSuccess {
                    farms,
                    reference_farms: vec![],
                },
                Err(err) => return Self::handle_err(&mut self.output_port, err),
            }
        };

        self.output_port.on_success(result);
        Ok(())
    }

    fn handle_err(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(ListFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<crate::shared::exceptions::RecordNotFoundError>().is_some() {
            output_port.on_failure(ListFailure::Error(Error::new(
                "Record not found".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(ListFailure::Error(Error::new(
                    record_invalid.to_string(),
                )));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct SpyOutput {
        success: Option<FarmListSuccess>,
        failure: Option<ListFailure>,
    }

    impl FarmListOutputPort for SpyOutput {
        fn on_success(&mut self, result: FarmListSuccess) {
            self.success = Some(result);
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_farm(id: i64) -> FarmEntity {
        FarmEntity {
            id,
            name: format!("Farm {id}"),
            latitude: None,
            longitude: None,
            region: None,
            user_id: Some(1),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    enum MockBehavior {
        Regular(Vec<FarmEntity>),
        Admin {
            list: Vec<FarmEntity>,
            reference: Vec<FarmEntity>,
        },
        PolicyDenied,
    }

    struct StubGateway {
        behavior: MockBehavior,
    }

    impl FarmGateway for StubGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Regular(farms) => Ok(farms.clone()),
                MockBehavior::PolicyDenied => Err(Box::new(PolicyPermissionDenied)),
                MockBehavior::Admin { .. } => unimplemented!(),
            }
        }

        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Admin { list, .. } => Ok(list.clone()),
                _ => unimplemented!(),
            }
        }

        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Admin { reference, .. } => Ok(reference.clone()),
                _ => unimplemented!(),
            }
        }
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_weather_progress(
            &self,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }
}

