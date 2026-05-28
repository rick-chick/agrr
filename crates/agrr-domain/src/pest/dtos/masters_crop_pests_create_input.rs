/// Ruby: `Domain::Pest::Dtos::MastersCropPestsCreateInput`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MastersCropPestsCreateInput {
    pub crop_id: i64,
    pub pest_id_raw: Option<i64>,
}

impl MastersCropPestsCreateInput {
    pub fn new(crop_id: i64, pest_id_raw: Option<i64>) -> Self {
        Self {
            crop_id,
            pest_id_raw,
        }
    }
}
