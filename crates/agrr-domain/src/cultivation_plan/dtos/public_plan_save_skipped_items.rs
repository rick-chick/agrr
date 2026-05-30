//! Skipped master-data ids during public plan save (Ruby `PlanSaveSession::Result#skipped_items`).

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct PublicPlanSaveSkippedItems {
    pub farm: Vec<i64>,
    pub fields: Vec<i64>,
    pub crops: Vec<i64>,
    pub fertilizes: Vec<i64>,
    pub pests: Vec<i64>,
    pub agricultural_tasks: Vec<i64>,
    pub pesticides: Vec<i64>,
    pub interaction_rules: Vec<i64>,
    pub plan: Vec<i64>,
}

impl PublicPlanSaveSkippedItems {
    pub fn add_skip(&mut self, category: &str, value: i64) {
        match category {
            "farm" => self.farm.push(value),
            "fields" => self.fields.push(value),
            "crops" => self.crops.push(value),
            "fertilizes" => self.fertilizes.push(value),
            "pests" => self.pests.push(value),
            "agricultural_tasks" => self.agricultural_tasks.push(value),
            "pesticides" => self.pesticides.push(value),
            "interaction_rules" => self.interaction_rules.push(value),
            "plan" => self.plan.push(value),
            _ => {}
        }
    }
}
