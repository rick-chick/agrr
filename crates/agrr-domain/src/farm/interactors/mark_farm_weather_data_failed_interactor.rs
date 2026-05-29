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
mod interactors_mark_farm_weather_data_failed_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_mark_farm_weather_data_failed_interactor_test.rs"));
}
