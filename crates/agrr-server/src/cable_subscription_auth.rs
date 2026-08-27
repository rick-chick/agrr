//! ActionCable subscription authorization — reuses domain policies.

use agrr_domain::cultivation_plan::entities::CultivationPlanEntity;
use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use agrr_domain::cultivation_plan::interactors::rest_plan_access_denied;
use agrr_domain::cultivation_plan::policies::{
    plan_read_authorization, private_cultivation_plan_access_policy,
};
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::shared::policies::farm_policy;
use agrr_domain::shared::user::User;

/// Session context resolved from `Cookie: session_id` at WebSocket upgrade.
#[derive(Debug, Clone)]
pub struct CableSessionContext {
    pub user_id: i64,
    pub member_organization_ids: Vec<i64>,
    pub user: User,
}

/// Returns `true` when the subscription must be rejected.
pub fn plan_subscription_denied(
    channel: &str,
    plan: &CultivationPlanEntity,
    session: Option<&CableSessionContext>,
) -> bool {
    match channel {
        "PlansOptimizationChannel" => match session {
            None => true,
            Some(ctx) => {
                let auth = CultivationPlanRestAuth::private_with_scope(
                    ctx.user_id,
                    ctx.member_organization_ids.clone(),
                );
                rest_plan_access_denied(plan, &auth)
            }
        },
        "OptimizationChannel" => {
            if plan_read_authorization::public_plan(&plan.plan_type) {
                return false;
            }
            match session {
                None => true,
                Some(ctx) => private_cultivation_plan_access_policy::access_denied(
                    plan,
                    ctx.user_id,
                    &ctx.member_organization_ids,
                ),
            }
        }
        _ => true,
    }
}

/// Returns `true` when the farm subscription must be rejected.
pub fn farm_subscription_denied(farm: &FarmEntity, session: Option<&CableSessionContext>) -> bool {
    match session {
        None => !farm.is_reference,
        Some(ctx) => !farm_policy::view_allowed(&ctx.user, farm.is_reference, farm.user_id),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn private_plan(user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 1,
            farm_id: 1,
            user_id,
            organization_id: None,
            total_area: 10.0,
            plan_type: "private".to_string(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: Some("pending".to_string()),
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    fn public_plan() -> CultivationPlanEntity {
        let mut plan = private_plan(1);
        plan.plan_type = "public".to_string();
        plan
    }

    fn farm_entity(user_id: Option<i64>, is_reference: bool) -> FarmEntity {
        FarmEntity {
            id: 1,
            name: "Farm".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
            region: None,
            user_id,
            organization_id: None,
            created_at: None,
            updated_at: None,
            is_reference,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    fn session(user_id: i64) -> CableSessionContext {
        CableSessionContext {
            user_id,
            member_organization_ids: vec![],
            user: User::new(user_id, false),
        }
    }

    #[test]
    fn plans_optimization_channel_denies_without_session() {
        let plan = private_plan(1);
        assert!(plan_subscription_denied("PlansOptimizationChannel", &plan, None));
    }

    #[test]
    fn plans_optimization_channel_denies_cross_user_private_plan() {
        let plan = private_plan(1);
        let attacker = session(2);
        assert!(plan_subscription_denied(
            "PlansOptimizationChannel",
            &plan,
            Some(&attacker)
        ));
    }

    #[test]
    fn plans_optimization_channel_allows_owner_private_plan() {
        let plan = private_plan(1);
        let owner = session(1);
        assert!(!plan_subscription_denied(
            "PlansOptimizationChannel",
            &plan,
            Some(&owner)
        ));
    }

    #[test]
    fn optimization_channel_allows_public_plan_without_session() {
        let plan = public_plan();
        assert!(!plan_subscription_denied("OptimizationChannel", &plan, None));
    }

    #[test]
    fn optimization_channel_denies_cross_user_private_plan() {
        let plan = private_plan(1);
        let attacker = session(2);
        assert!(plan_subscription_denied("OptimizationChannel", &plan, Some(&attacker)));
    }

    #[test]
    fn optimization_channel_allows_owner_private_plan() {
        let plan = private_plan(1);
        let owner = session(1);
        assert!(!plan_subscription_denied("OptimizationChannel", &plan, Some(&owner)));
    }

    #[test]
    fn farm_channel_denies_non_reference_without_session() {
        let farm = farm_entity(Some(1), false);
        assert!(farm_subscription_denied(&farm, None));
    }

    #[test]
    fn farm_channel_allows_reference_without_session() {
        let farm = farm_entity(None, true);
        assert!(!farm_subscription_denied(&farm, None));
    }

    #[test]
    fn farm_channel_denies_cross_user_non_reference() {
        let farm = farm_entity(Some(1), false);
        let attacker = session(2);
        assert!(farm_subscription_denied(&farm, Some(&attacker)));
    }

    #[test]
    fn farm_channel_allows_owner_non_reference() {
        let farm = farm_entity(Some(1), false);
        let owner = session(1);
        assert!(!farm_subscription_denied(&farm, Some(&owner)));
    }
}
