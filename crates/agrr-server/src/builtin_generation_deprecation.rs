//! RFC 9745 `Deprecation` / `Sunset` headers for built-in LLM generation endpoints ([#322](https://github.com/rick-chick/agrr/issues/322)).

use axum::http::header::{HeaderName, HeaderValue};
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::{json, Value};

/// HTTP-date when built-in generation endpoints will be removed ([#323](https://github.com/rick-chick/agrr/issues/323)).
pub const BUILTIN_GENERATION_SUNSET_HTTP_DATE: &str = "Sat, 18 Oct 2026 00:00:00 GMT";

/// RFC 9745 deprecation field: when the sunset was declared.
pub const BUILTIN_GENERATION_DEPRECATION_FIELD: &str = "@2026-07-18";

pub const BUILTIN_GENERATION_SUNSET_ISO_DATE: &str = "2026-10-18";

pub const MIGRATION_GUIDE_PATH: &str = "/docs/api/builtin-generation-sunset.md";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BuiltinGenerationEndpoint {
    CropAiCreate,
    FertilizeAiCreate,
    FertilizeAiUpdate,
    PestAiCreate,
    PestAiUpdate,
    TaskScheduleBlueprintRegenerate,
}

impl BuiltinGenerationEndpoint {
    pub fn alternative(self) -> &'static str {
        match self {
            Self::CropAiCreate => {
                "Create the crop with POST /api/v1/masters/crops, then apply a proposal with POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run|apply (see docs/api/builtin-generation-sunset.md and tools/agrr-mcp/)"
            }
            Self::FertilizeAiCreate | Self::FertilizeAiUpdate => {
                "Create or update fertilize masters with POST/PATCH /api/v1/masters/fertilizes; LLM generation is external (see docs/api/builtin-generation-sunset.md)"
            }
            Self::PestAiCreate | Self::PestAiUpdate => {
                "Create or update pest masters with POST/PATCH /api/v1/masters/pests; LLM generation is external (see docs/api/builtin-generation-sunset.md)"
            }
            Self::TaskScheduleBlueprintRegenerate => {
                "POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run|apply with task_schedule_blueprints in the proposal JSON (see docs/api/builtin-generation-sunset.md)"
            }
        }
    }
}

pub fn deprecation_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(
        HeaderName::from_static("deprecation"),
        HeaderValue::from_static(BUILTIN_GENERATION_DEPRECATION_FIELD),
    );
    headers.insert(
        HeaderName::from_static("sunset"),
        HeaderValue::from_static(BUILTIN_GENERATION_SUNSET_HTTP_DATE),
    );
    headers
}

pub fn enrich_deprecated_body(mut body: Value, endpoint: BuiltinGenerationEndpoint) -> Value {
    if let Some(obj) = body.as_object_mut() {
        obj.insert("deprecated".into(), json!(true));
        obj.insert(
            "deprecation".into(),
            json!({
                "sunset": BUILTIN_GENERATION_SUNSET_ISO_DATE,
                "alternative": endpoint.alternative(),
                "migration_guide": MIGRATION_GUIDE_PATH,
            }),
        );
    }
    body
}

pub fn builtin_generation_deprecated_json(
    status: StatusCode,
    body: Value,
    endpoint: BuiltinGenerationEndpoint,
) -> Response {
    let mut headers = deprecation_headers();
    headers.insert(
        axum::http::header::CONTENT_TYPE,
        HeaderValue::from_static("application/json"),
    );
    (
        status,
        headers,
        Json(enrich_deprecated_body(body, endpoint)),
    )
        .into_response()
}

pub fn builtin_generation_deprecated_result(
    result: Result<Json<Value>, (StatusCode, Json<Value>)>,
    endpoint: BuiltinGenerationEndpoint,
) -> Response {
    match result {
        Ok(json) => builtin_generation_deprecated_json(StatusCode::OK, json.0, endpoint),
        Err((status, json)) => builtin_generation_deprecated_json(status, json.0, endpoint),
    }
}

pub fn builtin_generation_deprecated_status_result(
    result: Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>,
    endpoint: BuiltinGenerationEndpoint,
) -> Response {
    match result {
        Ok((status, json)) => builtin_generation_deprecated_json(status, json.0, endpoint),
        Err((status, json)) => builtin_generation_deprecated_json(status, json.0, endpoint),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn enrich_deprecated_body_adds_metadata() {
        let body = json!({ "success": true });
        let enriched = enrich_deprecated_body(body, BuiltinGenerationEndpoint::CropAiCreate);
        assert_eq!(true, enriched["deprecated"].as_bool().unwrap());
        assert_eq!(
            BUILTIN_GENERATION_SUNSET_ISO_DATE,
            enriched["deprecation"]["sunset"].as_str().unwrap()
        );
        assert!(enriched["deprecation"]["alternative"]
            .as_str()
            .unwrap()
            .contains("setup_proposal"));
        assert_eq!(
            MIGRATION_GUIDE_PATH,
            enriched["deprecation"]["migration_guide"].as_str().unwrap()
        );
    }

    #[test]
    fn deprecation_headers_use_rfc_9745_fields() {
        let headers = deprecation_headers();
        assert_eq!(
            BUILTIN_GENERATION_DEPRECATION_FIELD,
            headers.get("deprecation").unwrap().to_str().unwrap()
        );
        assert_eq!(
            BUILTIN_GENERATION_SUNSET_HTTP_DATE,
            headers.get("sunset").unwrap().to_str().unwrap()
        );
    }

    #[test]
    fn alternative_messages_reference_migration_paths() {
        assert!(BuiltinGenerationEndpoint::CropAiCreate
            .alternative()
            .contains("setup_proposal"));
        assert!(BuiltinGenerationEndpoint::FertilizeAiCreate
            .alternative()
            .contains("fertilizes"));
        assert!(BuiltinGenerationEndpoint::FertilizeAiUpdate
            .alternative()
            .contains("fertilizes"));
        assert!(BuiltinGenerationEndpoint::PestAiCreate
            .alternative()
            .contains("pests"));
        assert!(BuiltinGenerationEndpoint::PestAiUpdate
            .alternative()
            .contains("pests"));
        assert!(BuiltinGenerationEndpoint::TaskScheduleBlueprintRegenerate
            .alternative()
            .contains("setup_proposal"));
    }

    #[test]
    fn builtin_generation_deprecated_result_wraps_ok_and_err() {
        let ok = builtin_generation_deprecated_result(
            Ok(Json(json!({"success": true}))),
            BuiltinGenerationEndpoint::CropAiCreate,
        );
        assert_eq!(ok.status(), StatusCode::OK);
        assert_eq!(
            ok.headers().get("deprecation").unwrap().to_str().unwrap(),
            BUILTIN_GENERATION_DEPRECATION_FIELD
        );

        let err = builtin_generation_deprecated_result(
            Err((StatusCode::UNPROCESSABLE_ENTITY, Json(json!({"error": "invalid"})))),
            BuiltinGenerationEndpoint::PestAiUpdate,
        );
        assert_eq!(err.status(), StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(
            err.headers().get("sunset").unwrap().to_str().unwrap(),
            BUILTIN_GENERATION_SUNSET_HTTP_DATE
        );
    }

    #[test]
    fn builtin_generation_deprecated_status_result_preserves_status_code() {
        let created = builtin_generation_deprecated_status_result(
            Ok((StatusCode::CREATED, Json(json!({"id": 1})))),
            BuiltinGenerationEndpoint::FertilizeAiCreate,
        );
        assert_eq!(created.status(), StatusCode::CREATED);
        assert_eq!(
            created.headers().get("deprecation").unwrap().to_str().unwrap(),
            BUILTIN_GENERATION_DEPRECATION_FIELD
        );
    }
}
