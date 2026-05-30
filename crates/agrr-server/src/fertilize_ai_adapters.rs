//! Fertilize AI create/update adapter ports (Ruby `FertilizeCreateForAiAdapter` / `FertilizeUpdateForAiAdapter`).

use crate::adapters::PassthroughTranslator;
use agrr_adapters_sqlite::{FertilizeSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::fertilize::dtos::FertilizeCreateInput;
use agrr_domain::fertilize::entities::FertilizeEntity;
use agrr_domain::fertilize::interactors::FertilizeCreateInteractor;
use agrr_domain::fertilize::interactors::FertilizeUpdateInteractor;
use agrr_domain::fertilize::ports::{
    AiCreateInteractorPort, AiCreateResult, AiUpdateInteractorPort, AiUpdateResult,
    FertilizeCreateOutputPort, FertilizeUpdateOutputPort,
};
use agrr_domain::fertilize::dtos::FertilizeUpdateInput;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use agrr_domain::fertilize::ports::CreateFailure;
use serde_json::Value;

pub struct FertilizeCreateForAiAdapter<'a> {
    user_id: i64,
    gateway: &'a FertilizeSqliteGateway,
    user_lookup: &'a UserLookupSqliteGateway,
    translator: &'a PassthroughTranslator,
}

impl<'a> FertilizeCreateForAiAdapter<'a> {
    pub fn new(
        user_id: i64,
        gateway: &'a FertilizeSqliteGateway,
        user_lookup: &'a UserLookupSqliteGateway,
        translator: &'a PassthroughTranslator,
    ) -> Self {
        Self {
            user_id,
            gateway,
            user_lookup,
            translator,
        }
    }
}

struct CreateCapture {
    result: Option<AiCreateResult>,
}

impl FertilizeCreateOutputPort for CreateCapture {
    fn on_success(&mut self, entity: FertilizeEntity) {
        self.result = Some(AiCreateResult {
            success: true,
            data: Some(entity),
            error: None,
        });
    }

    fn on_failure(&mut self, failure: CreateFailure) {
        let message = match failure {
            CreateFailure::Error(e) => e.message,
            CreateFailure::Policy(_) => "forbidden".into(),
        };
        self.result = Some(AiCreateResult {
            success: false,
            data: None,
            error: Some(message),
        });
    }
}

impl AiCreateInteractorPort for FertilizeCreateForAiAdapter<'_> {
    fn call(&self, attrs: AttrMap) -> AiCreateResult {
        let mut port = CreateCapture { result: None };
        let mut interactor = FertilizeCreateInteractor::new(
            &mut port,
            self.user_id,
            self.gateway,
            self.translator,
            self.user_lookup,
        );
        let input = fertilize_input_from_attrs(attrs);
        if interactor.call(input).is_err() {
            return AiCreateResult {
                success: false,
                data: None,
                error: Some("internal".into()),
            };
        }
        port.result.unwrap_or(AiCreateResult {
            success: false,
            data: None,
            error: Some("no response".into()),
        })
    }
}

pub struct FertilizeUpdateForAiAdapter<'a> {
    user_id: i64,
    gateway: &'a FertilizeSqliteGateway,
    user_lookup: &'a UserLookupSqliteGateway,
    translator: &'a PassthroughTranslator,
}

impl<'a> FertilizeUpdateForAiAdapter<'a> {
    pub fn new(
        user_id: i64,
        gateway: &'a FertilizeSqliteGateway,
        user_lookup: &'a UserLookupSqliteGateway,
        translator: &'a PassthroughTranslator,
    ) -> Self {
        Self {
            user_id,
            gateway,
            user_lookup,
            translator,
        }
    }
}

struct UpdateCapture {
    result: Option<AiUpdateResult>,
}

impl FertilizeUpdateOutputPort for UpdateCapture {
    fn on_success(&mut self, entity: FertilizeEntity) {
        self.result = Some(AiUpdateResult {
            success: true,
            data: Some(entity),
            error: None,
        });
    }

    fn on_failure(&mut self, failure: agrr_domain::fertilize::ports::UpdateFailure) {
        let message = match failure {
            agrr_domain::fertilize::ports::UpdateFailure::Policy(_) => "forbidden".into(),
            agrr_domain::fertilize::ports::UpdateFailure::Fertilize(f) => f.message,
        };
        self.result = Some(AiUpdateResult {
            success: false,
            data: None,
            error: Some(message),
        });
    }
}

impl AiUpdateInteractorPort for FertilizeUpdateForAiAdapter<'_> {
    fn call(&self, fertilize_id: i64, attrs: AttrMap) -> AiUpdateResult {
        let mut port = UpdateCapture { result: None };
        let mut interactor = FertilizeUpdateInteractor::new(
            &mut port,
            self.user_id,
            self.gateway,
            self.translator,
            self.user_lookup,
        );
        let input = fertilize_update_from_attrs(fertilize_id, attrs);
        if interactor.call(input).is_err() {
            return AiUpdateResult {
                success: false,
                data: None,
                error: Some("internal".into()),
            };
        }
        port.result.unwrap_or(AiUpdateResult {
            success: false,
            data: None,
            error: Some("no response".into()),
        })
    }
}

fn fertilize_input_from_attrs(attrs: AttrMap) -> FertilizeCreateInput {
    let mut input = FertilizeCreateInput::new(string_attr(&attrs, "name"));
    input.n = f64_attr(&attrs, "n");
    input.p = f64_attr(&attrs, "p");
    input.k = f64_attr(&attrs, "k");
    input.description = string_attr_opt(&attrs, "description");
    input.package_size = f64_attr(&attrs, "package_size");
    input.region = string_attr_opt(&attrs, "region");
    input.is_reference = attrs.get("is_reference").and_then(|v| match v {
        AttrValue::Bool(b) => Some(*b),
        _ => None,
    });
    input
}

fn fertilize_update_from_attrs(fertilize_id: i64, attrs: AttrMap) -> FertilizeUpdateInput {
    FertilizeUpdateInput {
        fertilize_id,
        name: string_attr_opt(&attrs, "name"),
        n: f64_attr(&attrs, "n"),
        p: f64_attr(&attrs, "p"),
        k: f64_attr(&attrs, "k"),
        description: string_attr_opt(&attrs, "description"),
        package_size: f64_attr(&attrs, "package_size"),
        region: string_attr_opt(&attrs, "region"),
        is_reference: attrs.get("is_reference").and_then(|v| match v {
            AttrValue::Bool(b) => Some(*b),
            _ => None,
        }),
    }
}

fn string_attr(attrs: &AttrMap, key: &str) -> String {
    attrs
        .get(key)
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

fn string_attr_opt(attrs: &AttrMap, key: &str) -> Option<String> {
    attrs.get(key).and_then(|v| v.as_str()).map(str::to_string)
}

fn f64_attr(attrs: &AttrMap, key: &str) -> Option<f64> {
    attrs.get(key).and_then(|v| match v {
        AttrValue::Int(i) => Some(*i as f64),
        AttrValue::Str(s) => s.parse().ok(),
        _ => None,
    })
}

pub fn attrs_from_fertilize_payload(data: &Value) -> AttrMap {
    let mut pairs: Vec<(&str, AttrValue)> = Vec::new();
    if let Some(name) = data.get("name").and_then(|v| v.as_str()) {
        pairs.push(("name", AttrValue::from(name)));
    }
    for key in ["n", "p", "k", "package_size"] {
        if let Some(n) = data.get(key).and_then(|v| v.as_f64()) {
            pairs.push((key, AttrValue::Str(n.to_string())));
        }
    }
    if let Some(desc) = data.get("description").and_then(|v| v.as_str()) {
        pairs.push(("description", AttrValue::from(desc)));
    }
    attr_map_from_pairs(pairs)
}
