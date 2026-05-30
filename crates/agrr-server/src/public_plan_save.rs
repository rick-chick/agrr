//! `POST /api/v1/public_plans/save_plan` — authenticated public plan → private copy.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanSqliteGateway, FarmSqliteGateway, PublicPlanSavePersistenceSqliteAdapter,
    PublicPlanSaveReadSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::{
    PublicPlanSaveFailure, PublicPlanSaveInput, PublicPlanSaveSuccess,
};
use agrr_domain::cultivation_plan::interactors::PublicPlanSaveInteractor;
use agrr_domain::cultivation_plan::ports::PublicPlanSaveFromSessionOutputPort;
use axum::{
    extract::State,
    http::StatusCode,
    routing::post,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/v1/public_plans/save_plan", post(save_plan))
}

#[derive(Deserialize)]
struct SavePlanBody {
    plan_id: Option<i64>,
}

struct SavePresenter {
    status: StatusCode,
    body: Value,
}

impl PublicPlanSaveFromSessionOutputPort for SavePresenter {
    fn on_success(&mut self, success: PublicPlanSaveSuccess) {
        self.status = StatusCode::OK;
        self.body = json!({
            "success": true,
            "cultivation_plan_id": success.cultivation_plan_id,
            "plan_reused": success.plan_reused,
        });
    }

    fn on_failure(&mut self, failure: PublicPlanSaveFailure) {
        let (status, error) = match failure.kind.as_str() {
            PublicPlanSaveFailure::KIND_MISSING_PLAN_ID => {
                (StatusCode::BAD_REQUEST, "plan_id is required".to_string())
            }
            PublicPlanSaveFailure::KIND_PLAN_NOT_FOUND => {
                (StatusCode::NOT_FOUND, "Plan not found".to_string())
            }
            PublicPlanSaveFailure::KIND_SAVE_FAILED => (
                StatusCode::UNPROCESSABLE_ENTITY,
                failure.message.unwrap_or_else(|| "Save failed".into()),
            ),
            _ => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error".to_string()),
        };
        self.status = status;
        self.body = json!({"success": false, "error": error});
    }
}

async fn save_plan(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<SavePlanBody>,
) -> (StatusCode, Json<Value>) {
    let user_id = match user_id_from_session(&state, &jar) {
        Ok(id) => id,
        Err(status) => {
            return (
                status,
                Json(json!({"success": false, "error": "unauthorized"})),
            );
        }
    };
    let pool = state.sqlite.clone();
    let read_gateway = PublicPlanSaveReadSqliteGateway::new(pool.clone());
    let farm_gateway = FarmSqliteGateway::new(pool.clone());
    let txn_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let persistence = PublicPlanSavePersistenceSqliteAdapter::new(pool);
    let logger = NoopLogger;
    let translator = PassthroughTranslator;
    let mut presenter = SavePresenter {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({"success": false, "error": "no response"}),
    };
    let input = PublicPlanSaveInput {
        plan_id: body.plan_id,
        user_id,
        session_data: None,
    };
    let mut interactor = PublicPlanSaveInteractor::new(
        &mut presenter,
        &txn_gateway,
        &read_gateway,
        &farm_gateway,
        &persistence,
        &logger,
        &translator,
    );
    if interactor.call(&input).is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        );
    }
    (presenter.status, Json(presenter.body))
}
