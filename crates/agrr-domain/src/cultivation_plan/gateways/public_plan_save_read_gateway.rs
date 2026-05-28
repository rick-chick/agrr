//! Ruby: `Domain::CultivationPlan::Gateways::PublicPlanSaveReadGateway`

use crate::cultivation_plan::dtos::{
    PublicPlanSaveAgriculturalTaskReferenceRow, PublicPlanSaveCropReferenceRow,
    PublicPlanSaveFertilizeReferenceRow, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    PublicPlanSaveInteractionRuleReferenceRow, PublicPlanSavePestReferenceRow,
    PublicPlanSavePesticideReferenceRow,
};

pub trait PublicPlanSaveReadGateway: Send + Sync {
    fn find_header(
        &self,
        plan_id: i64,
    ) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_field_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_crop_reference_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_pest_reference_rows(
        &self,
        plan_id: i64,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_pesticide_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_fertilize_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn exists_fertilize_name(&self, name: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>>;

    fn list_agricultural_task_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_interaction_rule_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>;
}
