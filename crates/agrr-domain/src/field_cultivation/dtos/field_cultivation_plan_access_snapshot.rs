//! Ruby: `Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot`

/// Ruby: `FieldCultivationPlanAccessSnapshot`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationPlanAccessSnapshot {
    pub field_cultivation_id: i64,
    pub plan_type_public: bool,
    pub plan_type_private: bool,
    pub plan_user_id: Option<i64>,
}

impl FieldCultivationPlanAccessSnapshot {
    pub fn new(
        field_cultivation_id: i64,
        plan_type_public: bool,
        plan_type_private: bool,
        plan_user_id: Option<i64>,
    ) -> Self {
        Self {
            field_cultivation_id,
            plan_type_public,
            plan_type_private,
            plan_user_id,
        }
    }

    pub fn plan_type_public(&self) -> bool {
        self.plan_type_public
    }

    pub fn plan_type_private(&self) -> bool {
        self.plan_type_private
    }
}
