use crate::field::dtos::{FieldCreateInput, FieldUpdateInput};
use crate::field::entities::FieldEntity;
use crate::field::results::{FarmFieldsList, FieldWithFarm};
use crate::shared::policies::farm_policy::FarmRecordAccessPolicy;
use crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter;

/// Ruby: `Domain::Field::Gateways::FieldGateway`
pub trait FieldGateway: Send + Sync {
    fn get_total_area_by_farm_id(&self, farm_id: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>>;

    fn farm_fields_list(
        &self,
        farm_id: i64,
    ) -> Result<FarmFieldsList, Box<dyn std::error::Error + Send + Sync>>;

    fn field_with_farm(
        &self,
        field_id: i64,
    ) -> Result<FieldWithFarm, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        create_input: &FieldCreateInput,
        farm_id: i64,
        farm_access_filter: &ReferenceRecordAccessFilter<FarmRecordAccessPolicy>,
    ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        field_id: i64,
        update_input: &FieldUpdateInput,
    ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        field_id: i64,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>>;
}
