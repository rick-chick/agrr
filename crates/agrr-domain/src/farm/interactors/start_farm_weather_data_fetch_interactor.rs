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
mod interactors_start_farm_weather_data_fetch_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_start_farm_weather_data_fetch_interactor_test.rs"));
}
