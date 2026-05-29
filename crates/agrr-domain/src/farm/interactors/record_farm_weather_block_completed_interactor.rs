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
mod interactors_record_farm_weather_block_completed_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_record_farm_weather_block_completed_interactor_test.rs"));
}
