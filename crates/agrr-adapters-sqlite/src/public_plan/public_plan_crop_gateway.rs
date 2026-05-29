//! `PublicPlanCropGateway` via `CropSqliteGateway`.

use crate::crop::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::public_plan::dtos::PublicPlanCrop;
use agrr_domain::public_plan::ports::PublicPlanCropGateway;
use agrr_domain::shared::exceptions::RecordInvalidError;

pub struct PublicPlanCropSqliteGateway {
    crop: CropSqliteGateway,
}

impl PublicPlanCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            crop: CropSqliteGateway::new(pool),
        }
    }
}

impl PublicPlanCropGateway for PublicPlanCropSqliteGateway {
    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanCrop>, RecordInvalidError> {
        self.crop
            .list_by_is_reference(is_reference, region)
            .map_err(|e| {
                if e.downcast_ref::<RecordInvalidError>().is_some() {
                    RecordInvalidError::new(Some(e.to_string()), None)
                } else {
                    RecordInvalidError::new(Some(e.to_string()), None)
                }
            })
            .map(|crops| {
                crops
                    .into_iter()
                    .map(|c| PublicPlanCrop {
                        id: c.id,
                        name: c.name,
                    })
                    .collect()
            })
    }
}
