//! Pest AI create/update adapter ports.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use agrr_adapters_sqlite::{
    CropPestSqliteGateway, PestCropSqliteGateway, PestSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::pest::dtos::PestCreateInput;
use agrr_domain::pest::entities::PestEntity;
use agrr_domain::pest::interactors::PestAssociateAffectedCropsInteractor;
use agrr_domain::pest::interactors::AssociateAffectedCropsRunner;
use agrr_domain::pest::interactors::PestCreateInteractor;
use agrr_domain::pest::interactors::PestUpdateInteractor;
use agrr_domain::pest::ports::{
    CreateFailure, PestAiCreateInteractorPort, PestAiCreateResult, PestAiUpdateInteractorPort,
    PestAiUpdateResult, PestCreateOutputPort, PestUpdateOutputPort, UpdateFailure,
};
use agrr_domain::pest::dtos::PestUpdateInput;
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use serde_json::Value;

pub struct PestCreateForAiAdapter<'a> {
    user_id: i64,
    gateway: &'a PestSqliteGateway,
    crop_gateway: &'a PestCropSqliteGateway,
    crop_pest_gateway: &'a CropPestSqliteGateway,
    user_lookup: &'a UserLookupSqliteGateway,
    translator: &'a PassthroughTranslator,
}

impl<'a> PestCreateForAiAdapter<'a> {
    pub fn new(
        user_id: i64,
        gateway: &'a PestSqliteGateway,
        crop_gateway: &'a PestCropSqliteGateway,
        crop_pest_gateway: &'a CropPestSqliteGateway,
        user_lookup: &'a UserLookupSqliteGateway,
        translator: &'a PassthroughTranslator,
    ) -> Self {
        Self {
            user_id,
            gateway,
            crop_gateway,
            crop_pest_gateway,
            user_lookup,
            translator,
        }
    }
}

struct PestCreateCapture {
    result: Option<PestAiCreateResult>,
}

impl PestCreateOutputPort for PestCreateCapture {
    fn on_success(&mut self, entity: PestEntity) {
        self.result = Some(PestAiCreateResult {
            success: true,
            data: Some(entity),
            error: None,
        });
    }

    fn on_failure(&mut self, failure: CreateFailure) {
        let message = match failure {
            CreateFailure::Error(e) => e.message,
        };
        self.result = Some(PestAiCreateResult {
            success: false,
            data: None,
            error: Some(message),
        });
    }
}

impl PestAiCreateInteractorPort for PestCreateForAiAdapter<'_> {
    fn call(&self, attrs: AttrMap) -> PestAiCreateResult {
        let mut port = PestCreateCapture { result: None };
        let mut interactor = PestCreateInteractor::new(
            &mut port,
            self.user_id,
            self.gateway,
            self.crop_gateway,
            self.crop_pest_gateway,
            self.translator,
            self.user_lookup,
        );
        let input = pest_create_input_from_attrs(attrs);
        if interactor.call(input).is_err() {
            return PestAiCreateResult {
                success: false,
                data: None,
                error: Some("internal".into()),
            };
        }
        port.result.unwrap_or(PestAiCreateResult {
            success: false,
            data: None,
            error: Some("no response".into()),
        })
    }
}

pub struct PestUpdateForAiAdapter<'a> {
    user_id: i64,
    gateway: &'a PestSqliteGateway,
    crop_gateway: &'a PestCropSqliteGateway,
    crop_pest_gateway: &'a CropPestSqliteGateway,
    user_lookup: &'a UserLookupSqliteGateway,
    translator: &'a PassthroughTranslator,
    logger: &'a NoopLogger,
}

impl<'a> PestUpdateForAiAdapter<'a> {
    pub fn new(
        user_id: i64,
        gateway: &'a PestSqliteGateway,
        crop_gateway: &'a PestCropSqliteGateway,
        crop_pest_gateway: &'a CropPestSqliteGateway,
        user_lookup: &'a UserLookupSqliteGateway,
        translator: &'a PassthroughTranslator,
        logger: &'a NoopLogger,
    ) -> Self {
        Self {
            user_id,
            gateway,
            crop_gateway,
            crop_pest_gateway,
            user_lookup,
            translator,
            logger,
        }
    }
}

struct PestUpdateCapture {
    result: Option<PestAiUpdateResult>,
}

impl PestUpdateOutputPort for PestUpdateCapture {
    fn on_success(&mut self, entity: PestEntity) {
        self.result = Some(PestAiUpdateResult {
            success: true,
            data: Some(entity),
            error: None,
        });
    }

    fn on_failure(&mut self, failure: UpdateFailure) {
        let message = match failure {
            UpdateFailure::Error(e) => e.message,
            UpdateFailure::Policy(_) => "forbidden".into(),
            UpdateFailure::ReferenceFlagChange(_) => "reference flag change denied".into(),
        };
        self.result = Some(PestAiUpdateResult {
            success: false,
            data: None,
            error: Some(message),
        });
    }
}

impl PestAiUpdateInteractorPort for PestUpdateForAiAdapter<'_> {
    fn call(&self, pest_id: i64, attrs: AttrMap) -> PestAiUpdateResult {
        let mut port = PestUpdateCapture { result: None };
        let mut interactor = PestUpdateInteractor::new(
            &mut port,
            self.user_id,
            self.gateway,
            self.crop_gateway,
            self.crop_pest_gateway,
            self.logger,
            self.translator,
            self.user_lookup,
        );
        let input = pest_update_input_from_attrs(pest_id, attrs);
        if interactor.call(input).is_err() {
            return PestAiUpdateResult {
                success: false,
                data: None,
                error: Some("internal".into()),
            };
        }
        port.result.unwrap_or(PestAiUpdateResult {
            success: false,
            data: None,
            error: Some("no response".into()),
        })
    }
}

pub struct AssociateAffectedCropsAdapter<'a> {
    user_id: i64,
    user_lookup: &'a UserLookupSqliteGateway,
    pest_gateway: &'a PestSqliteGateway,
    crop_gateway: &'a PestCropSqliteGateway,
    crop_pest_gateway: &'a CropPestSqliteGateway,
    logger: &'a NoopLogger,
}

impl<'a> AssociateAffectedCropsAdapter<'a> {
    pub fn new(
        user_id: i64,
        user_lookup: &'a UserLookupSqliteGateway,
        pest_gateway: &'a PestSqliteGateway,
        crop_gateway: &'a PestCropSqliteGateway,
        crop_pest_gateway: &'a CropPestSqliteGateway,
        logger: &'a NoopLogger,
    ) -> Self {
        Self {
            user_id,
            user_lookup,
            pest_gateway,
            crop_gateway,
            crop_pest_gateway,
            logger,
        }
    }
}

impl AssociateAffectedCropsRunner for AssociateAffectedCropsAdapter<'_> {
    fn call(
        &self,
        pest_id: i64,
        affected_crops: &[Value],
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let interactor = PestAssociateAffectedCropsInteractor::new(
            self.user_id,
            self.user_lookup,
            self.pest_gateway,
            self.crop_gateway,
            self.crop_pest_gateway,
            self.logger,
        );
        interactor.call(pest_id, affected_crops)
    }
}

fn pest_create_input_from_attrs(attrs: AttrMap) -> PestCreateInput {
    let mut input = PestCreateInput::new(
        attrs
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
    );
    input.name_scientific = str_opt(&attrs, "name_scientific");
    input.family = str_opt(&attrs, "family");
    input.order = str_opt(&attrs, "order");
    input.description = str_opt(&attrs, "description");
    input.occurrence_season = str_opt(&attrs, "occurrence_season");
    input.region = str_opt(&attrs, "region");
    input.crop_ids = vec![];
    input
}

fn pest_update_input_from_attrs(pest_id: i64, attrs: AttrMap) -> PestUpdateInput {
    PestUpdateInput {
        pest_id,
        name: str_opt(&attrs, "name"),
        name_scientific: str_opt(&attrs, "name_scientific"),
        family: str_opt(&attrs, "family"),
        order: str_opt(&attrs, "order"),
        description: str_opt(&attrs, "description"),
        occurrence_season: str_opt(&attrs, "occurrence_season"),
        region: str_opt(&attrs, "region"),
        is_reference: attrs.get("is_reference").and_then(|v| match v {
            AttrValue::Bool(b) => Some(*b),
            _ => None,
        }),
        pest_temperature_profile_attributes: None,
        pest_thermal_requirement_attributes: None,
        pest_control_methods_attributes: None,
        crop_ids: None,
    }
}

fn str_opt(attrs: &AttrMap, key: &str) -> Option<String> {
    attrs.get(key).and_then(|v| v.as_str()).map(str::to_string)
}
