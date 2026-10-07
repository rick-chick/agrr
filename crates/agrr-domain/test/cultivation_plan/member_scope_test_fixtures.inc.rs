struct MemberScopeGateway {
    org_ids: Vec<i64>,
}
impl crate::shared::gateways::UserOrganizationScopeGateway for MemberScopeGateway {
    fn organization_ids_for_user(
        &self,
        _: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.org_ids.clone())
    }
}

fn org_scoped_private_plan(
    id: i64,
    owner_user_id: i64,
    organization_id: i64,
) -> crate::cultivation_plan::entities::CultivationPlanEntity {
    crate::cultivation_plan::entities::CultivationPlanEntity {
        id,
        farm_id: 1,
        user_id: owner_user_id,
        organization_id: Some(organization_id),
        total_area: 0.0,
        plan_type: "private".into(),
        plan_year: None,
        plan_name: None,
        planning_start_date: None,
        planning_end_date: None,
        status: None,
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
