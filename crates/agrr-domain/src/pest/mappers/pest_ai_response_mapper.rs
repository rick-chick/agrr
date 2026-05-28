use crate::pest::dtos::{HttpStatus, PestAiCreateFailure};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use serde_json::Value;

/// Ruby: `Domain::Pest::Mappers::PestAiResponseMapper::Interpretation`
#[derive(Debug, Clone)]
pub struct PestAiInterpretation {
    pub failure: Option<PestAiCreateFailure>,
    pub pest_data: Option<Value>,
    pub affected_crops_from_agrr: Option<Value>,
}

pub fn interpret_pest_ai_response(
    pest_info: &Value,
    translator: &dyn TranslatorPort,
    validate_affected_crops_shape: bool,
) -> PestAiInterpretation {
    let opts = TranslateOptions::default();

    if pest_info.get("error_response").and_then(Value::as_bool) == Some(true) {
        let http_status = match pest_info.get("http_status").and_then(Value::as_str) {
            Some("unauthorized") => HttpStatus::Unauthorized,
            Some("bad_request") => HttpStatus::BadRequest,
            _ => HttpStatus::UnprocessableEntity,
        };
        let message = pest_info
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("error")
            .to_string();
        return PestAiInterpretation {
            failure: Some(PestAiCreateFailure::new(http_status, message)),
            pest_data: None,
            affected_crops_from_agrr: None,
        };
    }

    if pest_info.get("success").and_then(Value::as_bool) == Some(false) {
        let error_msg = pest_info
            .get("error")
            .and_then(Value::as_str)
            .map(str::to_string)
            .unwrap_or_else(|| {
                translator.t(
                    "api.errors.pests.fetch_failed",
                    &opts,
                )
            });
        let status_code = if pest_info.get("code").and_then(Value::as_str) == Some("daemon_not_running")
        {
            HttpStatus::ServiceUnavailable
        } else {
            HttpStatus::UnprocessableEntity
        };
        return PestAiInterpretation {
            failure: Some(PestAiCreateFailure::new(status_code, error_msg)),
            pest_data: None,
            affected_crops_from_agrr: None,
        };
    }

    let pest_data = pest_info
        .get("data")
        .and_then(|d| d.get("pest"))
        .cloned();
    if pest_data.is_none() {
        return PestAiInterpretation {
            failure: Some(PestAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                translator.t("api.errors.pests.invalid_payload", &opts),
            )),
            pest_data: None,
            affected_crops_from_agrr: None,
        };
    }

    let affected_crops_from_agrr = pest_info
        .get("data")
        .and_then(|d| d.get("affected_crops"))
        .cloned();
    if validate_affected_crops_shape {
        if let Some(ref crops) = affected_crops_from_agrr {
            if !crops.is_array() {
                return PestAiInterpretation {
                    failure: Some(PestAiCreateFailure::new(
                        HttpStatus::UnprocessableEntity,
                        translator.t("api.errors.pests.invalid_affected_crops", &opts),
                    )),
                    pest_data: None,
                    affected_crops_from_agrr: None,
                };
            }
        }
    }

    PestAiInterpretation {
        failure: None,
        pest_data,
        affected_crops_from_agrr,
    }
}
