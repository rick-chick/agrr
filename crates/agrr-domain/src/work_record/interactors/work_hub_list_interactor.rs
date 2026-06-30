//! Ruby: work hub farm list for authenticated users.

use crate::shared::dtos::Error;
use crate::shared::exceptions::{PersistenceFailedError, RecordInvalidError};
use crate::shared::ports::LoggerPort;
use crate::work_record::gateways::WorkHubReadGateway;
use crate::work_record::ports::WorkHubListOutputPort;

pub struct WorkHubListInteractor<'a, O, G, L> {
    output_port: &'a mut O,
    user_id: i64,
    gateway: &'a G,
    logger: &'a L,
}

impl<'a, O, G, L> WorkHubListInteractor<'a, O, G, L>
where
    O: WorkHubListOutputPort,
    G: WorkHubReadGateway,
    L: LoggerPort,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, logger: &'a L) -> Self {
        Self {
            output_port,
            user_id,
            gateway,
            logger,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.list_farm_rows_for_user(self.user_id) {
            Ok(rows) => {
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(err) if err.downcast_ref::<PersistenceFailedError>().is_some() => {
                self.logger.error(&format!("[WorkHubListInteractor] PersistenceFailed: {err}"));
                Err(err)
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.warn(&format!("[WorkHubListInteractor] RecordInvalid: {err}"));
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
