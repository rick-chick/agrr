//! Ruby: `Domain::Pest::Interactors::PestDetailInteractor`

use crate::pest::dtos::PestDetailOutput;
use crate::pest::gateways::PestGateway;
use crate::pest::ports::{DetailFailure, PestDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct PestDetailInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PestDetailInteractor<'a, G, O, U, T>
where
    G: PestGateway,
    O: PestDetailOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        pest_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pest_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let detail = match self.gateway.find_pest_show_detail(pest_id) {
            Ok(dto) => dto,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(_) =
            reference_record_authorization::assert_view_allowed(&access_filter, &detail.pest)
        {
            let message = self.translator.t("pests.flash.no_permission", &opts);
            self.output_port
                .on_failure(DetailFailure::Error(Error::new(message)));
            return Ok(());
        }

        self.output_port
            .on_success(PestDetailOutput::from_show_detail(detail));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::dtos::PestShowDetail;
    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator {
        message: Option<&'static str>,
    }

    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            if key == "pests.flash.no_permission" {
                self.message.unwrap_or(key).to_string()
            } else {
                key.to_string()
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    fn pest(is_reference: bool, user_id: Option<i64>) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(3),
            user_id,
            name: "p".into(),
            is_reference,
            ..Default::default()
        })
        .expect("valid")
    }

    struct DetailGateway {
        detail: PestShowDetail,
    }

    impl PestGateway for DetailGateway {

        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<PestShowDetail, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.detail.clone())
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::pest::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }
}

