//! Masters API route bundle with shared rate-limit middleware.

use crate::masters_rate_limit;
use crate::state::AppState;
use axum::{middleware, Router};

pub fn routes(state: AppState) -> Router<AppState> {
    Router::new()
        .merge(crate::masters_farms::routes())
        .merge(crate::masters_farm_temperature_chart::routes())
        .merge(crate::masters_fields::routes())
        .merge(crate::masters_crops::routes())
        .merge(crate::masters_crop_stages::routes())
        .merge(crate::masters_crop_pests::routes())
        .merge(crate::masters_crop_agricultural_tasks::routes())
        .merge(crate::masters_crop_task_schedule_blueprints::routes())
        .merge(crate::masters_crop_setup_proposal::routes())
        .merge(crate::masters_crop_pesticides::routes())
        .merge(crate::masters_crop_requirements::routes())
        .merge(crate::masters_pests::routes())
        .merge(crate::masters_fertilizes::routes())
        .merge(crate::masters_pesticides::routes())
        .merge(crate::masters_agricultural_tasks::routes())
        .merge(crate::masters_interaction_rules::routes())
        .route_layer(middleware::from_fn_with_state(
            state,
            masters_rate_limit::middleware,
        ))
}
