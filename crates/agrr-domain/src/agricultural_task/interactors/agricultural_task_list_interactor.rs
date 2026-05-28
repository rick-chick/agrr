//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor`

use crate::agricultural_task::dtos::AgriculturalTaskListInput;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::agricultural_task::ports::{AgriculturalTaskListOutputPort, ListFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::mappers::referencable_list_row_mapper;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct AgriculturalTaskListInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> AgriculturalTaskListInteractor<'a, G, O, L>
where
    G: AgriculturalTaskGateway,
    O: AgriculturalTaskListOutputPort,
    L: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a L) -> Self {
        Self { output_port, gateway, user_id, user_lookup }
    }

    pub fn call(
        &mut self,
        input: Option<AgriculturalTaskListInput>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let input = input.unwrap_or_else(AgriculturalTaskListInput::default_for_user);
        let user = self.user_lookup.find(self.user_id);
        let query = input.query.as_deref();
        let tasks = match list_tasks_for_input(self.gateway, &input, user.id, query) {
            Ok(t) => t,
            Err(err) => return self.handle_err(err),
        };
        let rows = referencable_list_row_mapper::map_records(&user, tasks);
        self.output_port.on_success(rows);
        Ok(())
    }

    fn handle_err(&mut self, err: Box<dyn std::error::Error + Send + Sync>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            self.output_port.on_failure(ListFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            self.output_port
                .on_failure(ListFailure::Error(Error::new("Record not found".to_string())));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(invalid) => {
                self.output_port
                    .on_failure(ListFailure::Error(Error::new(invalid.to_string())));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

fn list_tasks_for_input<G: AgriculturalTaskGateway>(
    gateway: &G,
    input: &AgriculturalTaskListInput,
    user_id: i64,
    query: Option<&str>,
) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
    if !input.is_admin {
        return gateway.list_user_owned_tasks(user_id, query);
    }
    match input.filter.as_str() {
        "user" => gateway.list_user_owned_tasks(user_id, query),
        "reference" => gateway.list_reference_tasks(query),
        _ => gateway.list_user_and_reference_tasks(user_id, query),
    }
}
