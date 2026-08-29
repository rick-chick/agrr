//! Ruby: `Domain::UserAccount::Interactors::UserAccountDeleteInteractor`

use crate::auth::gateways::UserSessionRevocationGateway;
use crate::user_account::dtos::UserAccountDeleteInput;
use crate::user_account::gateways::UserAccountGateway;
use crate::user_account::ports::UserAccountDeleteOutputPort;
use crate::work_record::gateways::WorkRecordPhotoObjectStoreGateway;

/// Ruby: `Domain::UserAccount::Interactors::UserAccountDeleteInteractor`
pub struct UserAccountDeleteInteractor<'a, G, O, R, S: ?Sized> {
    output_port: &'a mut O,
    account_gateway: &'a G,
    session_revocation_gateway: &'a R,
    photo_object_store: &'a S,
}

impl<'a, G, O, R, S> UserAccountDeleteInteractor<'a, G, O, R, S>
where
    G: UserAccountGateway,
    O: UserAccountDeleteOutputPort,
    R: UserSessionRevocationGateway,
    S: WorkRecordPhotoObjectStoreGateway + ?Sized,
{
    pub fn new(
        output_port: &'a mut O,
        account_gateway: &'a G,
        session_revocation_gateway: &'a R,
        photo_object_store: &'a S,
    ) -> Self {
        Self {
            output_port,
            account_gateway,
            session_revocation_gateway,
            photo_object_store,
        }
    }

    pub fn call(
        &mut self,
        input: UserAccountDeleteInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !input.confirm {
            self.output_port.on_not_confirmed();
            return Ok(());
        }

        let stored_email = self.account_gateway.user_email(input.user_id)?;
        if stored_email.is_some() {
            let email_confirm = match &input.email_confirm {
                Some(value) => value,
                None => {
                    self.output_port
                        .on_failure("Email confirmation required".into());
                    return Ok(());
                }
            };
            let matches = stored_email
                .as_deref()
                .is_some_and(|email| email == email_confirm.as_str());
            if !matches {
                self.output_port
                    .on_failure("Email confirmation does not match".into());
                return Ok(());
            }
        }

        self.session_revocation_gateway
            .delete_all_sessions_for_user(input.user_id);

        let photo_keys = self
            .account_gateway
            .list_photo_storage_keys(input.user_id)?;

        match self.account_gateway.delete_account(input.user_id) {
            Ok(()) => {
                for key in photo_keys {
                    self.photo_object_store.delete_object(&key)?;
                }
                self.output_port.on_success();
                Ok(())
            }
            Err(err) => {
                self.output_port.on_failure(err.to_string());
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_user_account_delete_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/user_account/interactors_user_account_delete_interactor_test.rs"
    ));
}
