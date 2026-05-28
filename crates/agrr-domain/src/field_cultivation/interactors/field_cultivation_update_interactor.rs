//! Ruby: `Domain::FieldCultivation::Interactors::FieldCultivationUpdateInteractor`

use time::Date;

use crate::field_cultivation::helpers::parse_iso_date;
use crate::field_cultivation::dtos::{
    FieldCultivationApiUpdateInput, FieldCultivationApiUpdateOutput,
};
use crate::field_cultivation::gateways::FieldCultivationGateway;
use crate::field_cultivation::interactors::plan_field_cultivation_authorization::{
    assert_field_cultivation_plan_access, assert_public_field_cultivation_plan_access,
};
use crate::field_cultivation::ports::{
    FieldCultivationApiUpdateOutputPort, FieldCultivationUpdateFailure,
};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct FieldCultivationUpdateInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: Option<i64>,
    user_lookup: Option<&'a L>,
    translator: Option<&'a T>,
}

impl<'a, G, O, L, T> FieldCultivationUpdateInteractor<'a, G, O, L, T>
where
    G: FieldCultivationGateway,
    O: FieldCultivationApiUpdateOutputPort,
    L: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
            user_id: None,
            user_lookup: None,
            translator: None,
        }
    }

    pub fn with_user(
        output_port: &'a mut O,
        gateway: &'a G,
        user_id: i64,
        user_lookup: &'a L,
        translator: Option<&'a T>,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id: Some(user_id),
            user_lookup: Some(user_lookup),
            translator,
        }
    }

    pub fn call(
        &mut self,
        input: FieldCultivationApiUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let (Some(user_id), Some(lookup)) = (self.user_id, self.user_lookup) {
            let user = lookup.find(user_id);
            if let Err(err) = assert_field_cultivation_plan_access(
                &user,
                self.gateway,
                input.field_cultivation_id,
                true,
            ) {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port
                        .on_failure(FieldCultivationUpdateFailure::Message(Error::new(
                            "Forbidden",
                        )));
                    return Ok(());
                }
                return Err(err);
            }
        } else if let Err(err) = assert_public_field_cultivation_plan_access(
            self.gateway,
            input.field_cultivation_id,
        ) {
            if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                self.output_port
                    .on_failure(FieldCultivationUpdateFailure::Message(Error::new("Forbidden")));
                return Ok(());
            }
            return Err(err);
        }

        let cultivation_days = if input.public_plan() {
            match (
                parse_date(&input.start_date),
                parse_date(&input.completion_date),
            ) {
                (Some(start), Some(end)) => Some((end - start).whole_days() as i32 + 1),
                _ => None,
            }
        } else {
            None
        };

        match self.gateway.update_field_cultivation_schedule(
            input.field_cultivation_id,
            &input.start_date,
            &input.completion_date,
            cultivation_days,
        ) {
            Ok(mut dto) => {
                if input.public_plan() {
                    let message = public_plan_update_message(self.translator);
                    dto = FieldCultivationApiUpdateOutput {
                        field_cultivation_id: dto.field_cultivation_id,
                        start_date: dto.start_date,
                        completion_date: dto.completion_date,
                        cultivation_days: dto.cultivation_days,
                        message: Some(message),
                    };
                }
                self.output_port.on_success(dto);
                Ok(())
            }
            Err(err) if err.downcast_ref::<PolicyPermissionDenied>().is_some() => {
                self.output_port
                    .on_failure(FieldCultivationUpdateFailure::Message(Error::new("Forbidden")));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(FieldCultivationUpdateFailure::Message(Error::new(
                    err.to_string(),
                )));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                self.output_port.on_failure(FieldCultivationUpdateFailure::RecordInvalid(
                    *err.downcast::<RecordInvalidError>().unwrap(),
                ));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

fn parse_date(value: &str) -> Option<Date> {
    parse_iso_date(value)
}

fn public_plan_update_message<T: TranslatorPort>(translator: Option<&T>) -> String {
    const DEFAULT: &str = "栽培期間を更新しました";
    let Some(translator) = translator else {
        return DEFAULT.into();
    };
    let key = "field_cultivations.update.success";
    let translated = translator.t(key, &TranslateOptions::new());
    if translated == key {
        DEFAULT.into()
    } else {
        translated
    }
}
