//! Ruby: `Domain::Farm::Interactors::MarkFarmWeatherDataFailedInteractor`

use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::farm::dtos::MarkFarmWeatherDataFailedInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;

pub struct MarkFarmWeatherDataFailedInteractor<'a, G> {
    farm_gateway: &'a G,
}

impl<'a, G> MarkFarmWeatherDataFailedInteractor<'a, G>
where
    G: FarmGateway,
{
    pub fn new(farm_gateway: &'a G) -> Self {
        Self { farm_gateway }
    }

    pub fn call(
        &self,
        input: MarkFarmWeatherDataFailedInput,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        let attrs =
            FarmWeatherProgressCalculator::failed_attrs(&input.error_message);
        self.farm_gateway
            .update_weather_progress(input.farm_id, attrs)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::farm::entities::FarmEntity;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;
    use std::sync::Mutex;

    struct SpyGateway {
        updated: Mutex<Option<(i64, AttrMap)>>,
        result: FarmEntity,
    }

    impl FarmGateway for SpyGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_weather_progress(
            &self,
            farm_id: i64,
            attrs: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            *self.updated.lock().unwrap() = Some((farm_id, attrs));
            Ok(self.result.clone())
        }
        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    // Ruby: test "persists failed status and error message via gateway"
    #[test]
    fn persists_failed_status_and_error_message_via_gateway() {
        let expected_attrs =
            FarmWeatherProgressCalculator::failed_attrs("daemon timeout");
        let result_entity = FarmEntity {
            id: 7,
            name: "F".into(),
            latitude: None,
            longitude: None,
            region: None,
            user_id: None,
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: Some("failed".into()),
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: Some("daemon timeout".into()),
            weather_location_id: None,
            last_broadcast_at: None,
        };
        let gateway = SpyGateway {
            updated: Mutex::new(None),
            result: result_entity.clone(),
        };
        let interactor = MarkFarmWeatherDataFailedInteractor::new(&gateway);

        let updated = interactor
            .call(MarkFarmWeatherDataFailedInput {
                farm_id: 7,
                error_message: "daemon timeout".into(),
            })
            .unwrap();

        assert_eq!(updated.id, result_entity.id);
        let stored = gateway.updated.lock().unwrap();
        let (farm_id, attrs) = stored.as_ref().expect("update called");
        assert_eq!(*farm_id, 7);
        assert_eq!(attrs, &expected_attrs);
    }
}
