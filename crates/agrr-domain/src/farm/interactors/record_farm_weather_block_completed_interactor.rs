//! Ruby: `Domain::Farm::Interactors::RecordFarmWeatherBlockCompletedInteractor`

use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::farm::dtos::RecordFarmWeatherBlockCompletedInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::shared::ports::FarmRefreshBroadcastPort;
use serde_json::json;

pub struct RecordFarmWeatherBlockCompletedInteractor<'a, G, B> {
    farm_gateway: &'a G,
    farm_refresh_broadcast_port: Option<&'a B>,
}

impl<'a, G, B> RecordFarmWeatherBlockCompletedInteractor<'a, G, B>
where
    G: FarmGateway,
    B: FarmRefreshBroadcastPort,
{
    pub fn new(farm_gateway: &'a G, farm_refresh_broadcast_port: Option<&'a B>) -> Self {
        Self {
            farm_gateway,
            farm_refresh_broadcast_port,
        }
    }

    pub fn call(
        &self,
        input: RecordFarmWeatherBlockCompletedInput,
    ) -> Result<Option<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let farm = self.farm_gateway.find_by_id(input.farm_id)?;
        let (attrs, throttle_ok) = FarmWeatherProgressCalculator::next_after_block(
            farm.weather_data_fetched_years,
            farm.weather_data_total_years,
            farm.last_broadcast_at,
            input.current_time,
            0.5,
        );
        if attrs.is_empty() {
            return Ok(None);
        }

        let updated = self
            .farm_gateway
            .update_weather_progress(input.farm_id, attrs)?;
        self.broadcast_if_needed(input.farm_id, &updated, throttle_ok);
        Ok(Some(updated))
    }

    fn broadcast_if_needed(&self, farm_id: i64, farm: &FarmEntity, throttle_ok: bool) {
        let Some(port) = self.farm_refresh_broadcast_port else {
            return;
        };
        if !throttle_ok {
            return;
        }
        let payload = json!({
            "id": farm.id,
            "weather_data_status": farm.weather_data_status,
            "weather_data_progress": farm.weather_data_progress(),
            "weather_data_fetched_years": farm.weather_data_fetched_years,
            "weather_data_total_years": farm.weather_data_total_years,
        });
        port.broadcast_farm_weather_progress(farm_id, &payload);
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
        farm: FarmEntity,
        updated_attrs: Mutex<Option<AttrMap>>,
        updated_farm: FarmEntity,
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
            farm_id: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(farm_id, 5);
            Ok(self.farm.clone())
        }
        fn update_weather_progress(
            &self,
            farm_id: i64,
            attrs: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(farm_id, 5);
            *self.updated_attrs.lock().unwrap() = Some(attrs);
            Ok(self.updated_farm.clone())
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

    struct SpyBroadcast {
        calls: Mutex<Vec<(i64, serde_json::Value)>>,
    }

    impl FarmRefreshBroadcastPort for SpyBroadcast {
        fn broadcast_farm_weather_progress(&self, farm_id: i64, payload: &serde_json::Value) {
            self.calls
                .lock()
                .unwrap()
                .push((farm_id, payload.clone()));
        }
    }

    fn build_farm(fetched: i32, total: i32, last_broadcast_at: Option<f64>) -> FarmEntity {
        FarmEntity {
            id: 5,
            name: "Farm".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
            region: Some("jp".into()),
            user_id: Some(1),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_fetched_years: Some(fetched),
            weather_data_total_years: Some(total),
            weather_data_status: Some("fetching".into()),
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at,
        }
    }

    // Ruby: test "returns nil without gateway update when progress already complete"
    #[test]
    fn returns_nil_without_gateway_update_when_progress_already_complete() {
        let gateway = SpyGateway {
            farm: build_farm(3, 3, None),
            updated_attrs: Mutex::new(None),
            updated_farm: build_farm(3, 3, None),
        };
        let broadcast = SpyBroadcast {
            calls: Mutex::new(vec![]),
        };
        let interactor = RecordFarmWeatherBlockCompletedInteractor::new(
            &gateway,
            Some(&broadcast),
        );
        let current_time = 1_748_515_200.0;
        let input = RecordFarmWeatherBlockCompletedInput {
            farm_id: 5,
            current_time,
        };

        assert!(interactor.call(input).unwrap().is_none());
        assert!(gateway.updated_attrs.lock().unwrap().is_none());
        assert!(broadcast.calls.lock().unwrap().is_empty());
    }

    // Ruby: test "increments fetched years and broadcasts when throttle allows"
    #[test]
    fn increments_fetched_years_and_broadcasts_when_throttle_allows() {
        let current_time = 1_748_515_200.0;
        let farm = build_farm(0, 2, None);
        let updated = build_farm(1, 2, Some(current_time));
        let (expected_attrs, _) = FarmWeatherProgressCalculator::next_after_block(
            Some(0),
            Some(2),
            None,
            current_time,
            0.5,
        );
        let gateway = SpyGateway {
            farm: farm.clone(),
            updated_attrs: Mutex::new(None),
            updated_farm: updated.clone(),
        };
        let broadcast = SpyBroadcast {
            calls: Mutex::new(vec![]),
        };
        let interactor = RecordFarmWeatherBlockCompletedInteractor::new(
            &gateway,
            Some(&broadcast),
        );

        let result = interactor
            .call(RecordFarmWeatherBlockCompletedInput {
                farm_id: 5,
                current_time,
            })
            .unwrap()
            .expect("updated farm");

        assert_eq!(result.id, updated.id);
        assert_eq!(
            gateway.updated_attrs.lock().unwrap().as_ref(),
            Some(&expected_attrs)
        );
        let calls = broadcast.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, 5);
        assert_eq!(calls[0].1["id"], 5);
        assert_eq!(calls[0].1["weather_data_fetched_years"], 1);
        assert_eq!(calls[0].1["weather_data_total_years"], 2);
    }

    // Ruby: test "updates progress without broadcast port"
    #[test]
    fn updates_progress_without_broadcast_port() {
        let current_time = 1_748_515_200.0;
        let farm = build_farm(0, 2, None);
        let updated = build_farm(1, 2, None);
        let (expected_attrs, _) = FarmWeatherProgressCalculator::next_after_block(
            Some(0),
            Some(2),
            None,
            current_time,
            0.5,
        );
        let gateway = SpyGateway {
            farm,
            updated_attrs: Mutex::new(None),
            updated_farm: updated.clone(),
        };
        let interactor: RecordFarmWeatherBlockCompletedInteractor<'_, SpyGateway, SpyBroadcast> =
            RecordFarmWeatherBlockCompletedInteractor::new(&gateway, None);

        let result = interactor
            .call(RecordFarmWeatherBlockCompletedInput {
                farm_id: 5,
                current_time,
            })
            .unwrap()
            .expect("updated");

        assert_eq!(result.id, updated.id);
        assert_eq!(
            gateway.updated_attrs.lock().unwrap().as_ref(),
            Some(&expected_attrs)
        );
    }
}
