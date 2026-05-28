//! Ruby: `Domain::Pest::Interactors::PestUpdateCropAssociationsInteractor`

use crate::pest::dtos::PestCropAssociationSyncResult;
use crate::pest::gateways::CropPestGateway;
use crate::pest::services::CropPestAssociationSync;

pub struct PestUpdateCropAssociationsInteractor<'a, G> {
    sync: CropPestAssociationSync<'a, G>,
}

impl<'a, G: CropPestGateway> PestUpdateCropAssociationsInteractor<'a, G> {
    pub fn new(crop_pest_gateway: &'a G) -> Self {
        Self {
            sync: CropPestAssociationSync::new(crop_pest_gateway),
        }
    }

    pub fn call(
        &self,
        pest_id: i64,
        crop_ids: &[i64],
    ) -> Result<PestCropAssociationSyncResult, Box<dyn std::error::Error + Send + Sync>> {
        self.sync.replace_all(pest_id, crop_ids)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::entities::CropPestLinkEntity;
    use std::collections::HashMap;
    use std::sync::Mutex;

    struct MockCropPestGateway {
        links: Mutex<HashMap<(i64, i64), CropPestLinkEntity>>,
        list: Mutex<Vec<i64>>,
    }

    impl CropPestGateway for MockCropPestGateway {
        fn find_by_crop_id_and_pest_id(
            &self,
            crop_id: i64,
            pest_id: i64,
        ) -> Result<Option<CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .links
                .lock()
                .expect("lock")
                .get(&(crop_id, pest_id))
                .cloned())
        }

        fn list_by_pest_id(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.list.lock().expect("lock").clone())
        }

        fn create(
            &self,
            crop_id: i64,
            pest_id: i64,
        ) -> Result<CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>> {
            let link = CropPestLinkEntity::new(1, crop_id, pest_id);
            self.links
                .lock()
                .expect("lock")
                .insert((crop_id, pest_id), link.clone());
            Ok(link)
        }

        fn delete(
            &self,
            crop_id: i64,
            pest_id: i64,
        ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .links
                .lock()
                .expect("lock")
                .remove(&(crop_id, pest_id))
                .is_some())
        }
    }

    // Ruby: test "replaces associations with add and remove counts"
    #[test]
    fn replaces_associations_with_counts() {
        let gateway = MockCropPestGateway {
            links: Mutex::new(HashMap::new()),
            list: Mutex::new(vec![1, 2]),
        };
        {
            let mut links = gateway.links.lock().expect("lock");
            links.insert((1, 5), CropPestLinkEntity::new(8, 1, 5));
            links.insert((2, 5), CropPestLinkEntity::new(9, 2, 5));
        }

        let interactor = PestUpdateCropAssociationsInteractor::new(&gateway);
        let result = interactor.call(5, &[2, 3]).expect("ok");

        assert_eq!(result.added, 1);
        assert_eq!(result.removed, 1);
    }
}
