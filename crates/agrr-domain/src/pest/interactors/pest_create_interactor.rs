//! Ruby: `Domain::Pest::Interactors::PestCreateInteractor`

use crate::pest::dtos::PestCreateInput;
use crate::pest::entities::PestEntity;
use crate::pest::gateways::{CropGateway, CropPestGateway, PestGateway};
use crate::pest::ports::{CreateFailure, PestCreateOutputPort};
use crate::pest::services::{CropPestAssociationSync, FilterAssociableCropIds};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::policies::referencable_resource_policy::{
    reference_assignment_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::type_converters::cast_boolean_attr;

pub struct PestCreateInteractor<'a, G, CG, CPG, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    crop_gateway: &'a CG,
    crop_pest_gateway: &'a CPG,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, CG, CPG, O, U, T> PestCreateInteractor<'a, G, CG, CPG, O, U, T>
where
    G: PestGateway,
    CG: CropGateway,
    CPG: CropPestGateway,
    O: PestCreateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        crop_gateway: &'a CG,
        crop_pest_gateway: &'a CPG,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            crop_gateway,
            crop_pest_gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: PestCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();
        let is_reference = input.is_reference.unwrap_or(false);

        if !reference_assignment_allowed(&user, is_reference) {
            let message = self
                .translator
                .t("pests.flash.reference_only_admin", &opts);
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        let mut pairs: Vec<(&str, AttrValue)> = vec![("name", AttrValue::from(input.name.as_str()))];
        if let Some(v) = input.name_scientific.as_deref() {
            pairs.push(("name_scientific", AttrValue::from(v)));
        }
        if let Some(v) = input.family.as_deref() {
            pairs.push(("family", AttrValue::from(v)));
        }
        if let Some(v) = input.order.as_deref() {
            pairs.push(("order", AttrValue::from(v)));
        }
        if let Some(v) = input.description.as_deref() {
            pairs.push(("description", AttrValue::from(v)));
        }
        if let Some(v) = input.occurrence_season.as_deref() {
            pairs.push(("occurrence_season", AttrValue::from(v)));
        }
        if let Some(v) = input.region.as_deref() {
            pairs.push(("region", AttrValue::from(v)));
        }
        pairs.push(("is_reference", AttrValue::Bool(is_reference)));

        let attrs = pest_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs(pairs),
            false,
        );
        let effective_reference = attrs
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(false);
        let effective_user_id = match attrs.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) | None => None,
            _ => None,
        };

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.pest.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.create_for_user(&user, attrs) {
            Ok(pest_entity) => {
                if !input.crop_ids.is_empty() {
                    let crop_ids = FilterAssociableCropIds::for_pest_update(
                        &input.crop_ids,
                        &pest_entity,
                        &user,
                        self.crop_gateway,
                    )?;
                    CropPestAssociationSync::new(self.crop_pest_gateway)
                        .add_missing(pest_entity.id, &crop_ids)?;
                }
                self.output_port.on_success(pest_entity);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CreateFailure::Error(Error::new(
                        record_invalid.to_string(),
                    )));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyGateway {
        entity: PestEntity,
    }

    impl PestGateway for SpyGateway {

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
            attrs: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
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
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
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

