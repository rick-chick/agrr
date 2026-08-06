//! Ruby: `Domain::UserAccount::Interactors::UserDataExportInteractor`

use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

use crate::user_account::dtos::UserDataExportFailure;
use crate::user_account::gateways::UserAccountGateway;
use crate::user_account::ports::UserDataExportOutputPort;

/// Ruby: `Domain::UserAccount::Interactors::UserDataExportInteractor`
pub struct UserDataExportInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> UserDataExportInteractor<'a, G, O>
where
    G: UserAccountGateway,
    O: UserDataExportOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.export_data(user_id) {
            Ok(mut export) => {
                export.exported_at = OffsetDateTime::now_utc()
                    .format(&Rfc3339)
                    .unwrap_or_else(|_| String::new());
                self.output_port.on_success(export);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(UserDataExportFailure::new(err.to_string()));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_user_data_export_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/user_account/interactors_user_data_export_interactor_test.rs"
    ));
}
