//! Ruby: `Domain::CultivationPlan::Interactors::PrivateOwnedPlansListInteractor`

use crate::cultivation_plan::gateways::CultivationPlanPrivateReadGateway;
use crate::cultivation_plan::ports::PrivateOwnedPlansListOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{PersistenceFailedError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::ports::LoggerPort;

pub struct PrivateOwnedPlansListInteractor<'a, O, G, U, T, L> {
    output_port: &'a mut O,
    user_id: i64,
    private_read_gateway: &'a G,
    translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
}

impl<'a, O, G, U, T, L> PrivateOwnedPlansListInteractor<'a, O, G, U, T, L>
where
    O: PrivateOwnedPlansListOutputPort,
    G: CultivationPlanPrivateReadGateway,
    U: UserLookupGateway,
    T: TranslatorPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        private_read_gateway: &'a G,
        translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            user_id,
            private_read_gateway,
            translator,
            logger,
            user_lookup,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self
            .private_read_gateway
            .list_private_plan_index_rows_by_user_id(user.id)
        {
            Ok(rows) => {
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn(&format!(
                    "[PrivateOwnedPlansListInteractor] RecordNotFound: {err}"
                ));
                let message = self.translator.t(
                    "plans.errors.session_invalid",
                    &TranslateOptions::default(),
                );
                self.output_port.on_failure(Error::new(message));
                Ok(())
            }
            Err(err) if err.downcast_ref::<PersistenceFailedError>().is_some() => {
                self.logger.error(&format!(
                    "[PrivateOwnedPlansListInteractor] PersistenceFailed: {err}"
                ));
                Err(err)
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.warn(&format!(
                    "[PrivateOwnedPlansListInteractor] RecordInvalid: {err}"
                ));
                let message = invalid
                    .detail_message()
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| invalid.to_string());
                self.output_port.on_failure(Error::new(message));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
