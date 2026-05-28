//! Ruby: `Domain::Farm::Interactors::StartFarmWeatherDataFetchInteractor`

use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::farm::dtos::StartFarmWeatherDataFetchInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::shared::ports::FetchWeatherDataEnqueuePort;

pub struct StartFarmWeatherDataFetchInteractor<'a, G, E> {
    farm_gateway: &'a G,
    fetch_weather_data_enqueue_port: &'a E,
}

impl<'a, G, E> StartFarmWeatherDataFetchInteractor<'a, G, E>
where
    G: FarmGateway,
    E: FetchWeatherDataEnqueuePort,
{
    pub fn new(farm_gateway: &'a G, fetch_weather_data_enqueue_port: &'a E) -> Self {
        Self {
            farm_gateway,
            fetch_weather_data_enqueue_port,
        }
    }

    pub fn call(
        &self,
        input: StartFarmWeatherDataFetchInput,
    ) -> Result<Option<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let farm = self.farm_gateway.find_by_id(input.farm_id)?;
        if !farm.has_coordinates() {
            return Ok(None);
        }

        let as_of_year = input.as_of.year();
        let attrs = FarmWeatherProgressCalculator::start_fetch_attrs(as_of_year);
        self.farm_gateway
            .update_weather_progress(input.farm_id, attrs)?;

        let blocks = FarmWeatherProgressCalculator::weather_fetch_date_blocks(input.as_of);
        let (lat, lon) = farm.coordinates();
        self.fetch_weather_data_enqueue_port.enqueue_farm_weather_fetch(
            farm.id,
            lat.unwrap_or(0.0),
            lon.unwrap_or(0.0),
            &blocks,
        );

        Ok(Some(farm))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::farm::entities::FarmEntity;
    use crate::shared::attr::AttrMap;
    use crate::shared::dtos::WeatherFetchDateBlock;
    use crate::shared::user::User;
    use std::sync::Mutex;
    use time::{Date, Month};

    struct SpyGateway {
        farm: FarmEntity,
        updated_attrs: Mutex<Option<AttrMap>>,
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
            assert_eq!(farm_id, 10);
            Ok(self.farm.clone())
        }
        fn update_weather_progress(
            &self,
            farm_id: i64,
            attrs: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(farm_id, 10);
            *self.updated_attrs.lock().unwrap() = Some(attrs);
            Ok(self.farm.clone())
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

    struct SpyEnqueue {
        calls: Mutex<Vec<(i64, f64, f64, Vec<WeatherFetchDateBlock>)>>,
    }

    impl FetchWeatherDataEnqueuePort for SpyEnqueue {
        fn enqueue_farm_weather_fetch(
            &self,
            farm_id: i64,
            latitude: f64,
            longitude: f64,
            blocks: &[WeatherFetchDateBlock],
        ) {
            self.calls.lock().unwrap().push((
                farm_id,
                latitude,
                longitude,
                blocks.to_vec(),
            ));
        }
    }

    fn build_farm(latitude: Option<f64>, longitude: Option<f64>) -> FarmEntity {
        FarmEntity {
            id: 10,
            name: "Test Farm".into(),
            latitude,
            longitude,
            region: Some("jp".into()),
            user_id: Some(1),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    // Ruby: test "returns nil without updating or enqueueing when farm lacks coordinates"
    #[test]
    fn returns_nil_without_updating_or_enqueueing_when_farm_lacks_coordinates() {
        let gateway = SpyGateway {
            farm: build_farm(None, Some(139.0)),
            updated_attrs: Mutex::new(None),
        };
        let enqueue = SpyEnqueue {
            calls: Mutex::new(vec![]),
        };
        let interactor =
            StartFarmWeatherDataFetchInteractor::new(&gateway, &enqueue);
        let as_of = Date::from_calendar_date(2026, Month::May, 29).unwrap();
        let input = StartFarmWeatherDataFetchInput {
            farm_id: 10,
            as_of,
        };

        assert!(interactor.call(input).unwrap().is_none());
        assert!(gateway.updated_attrs.lock().unwrap().is_none());
        assert!(enqueue.calls.lock().unwrap().is_empty());
    }

    // Ruby: test "updates progress and enqueues weather fetch blocks when farm has coordinates"
    #[test]
    fn updates_progress_and_enqueues_weather_fetch_blocks_when_farm_has_coordinates() {
        let farm = build_farm(Some(35.0), Some(139.0));
        let gateway = SpyGateway {
            farm: farm.clone(),
            updated_attrs: Mutex::new(None),
        };
        let enqueue = SpyEnqueue {
            calls: Mutex::new(vec![]),
        };
        let interactor =
            StartFarmWeatherDataFetchInteractor::new(&gateway, &enqueue);
        let as_of = Date::from_calendar_date(2026, Month::May, 29).unwrap();
        let expected_attrs =
            FarmWeatherProgressCalculator::start_fetch_attrs(as_of.year());
        let expected_blocks =
            FarmWeatherProgressCalculator::weather_fetch_date_blocks(as_of);

        let result = interactor
            .call(StartFarmWeatherDataFetchInput {
                farm_id: 10,
                as_of,
            })
            .unwrap()
            .expect("farm returned");

        assert_eq!(result.id, farm.id);
        assert_eq!(
            gateway.updated_attrs.lock().unwrap().as_ref(),
            Some(&expected_attrs)
        );
        let calls = enqueue.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, 10);
        assert_eq!(calls[0].1, 35.0);
        assert_eq!(calls[0].2, 139.0);
        assert_eq!(calls[0].3, expected_blocks);
    }
}
