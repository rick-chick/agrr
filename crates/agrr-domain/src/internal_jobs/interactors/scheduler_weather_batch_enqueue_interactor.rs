use crate::internal_jobs::dtos::SchedulerWeatherFarmRow;
use crate::internal_jobs::gateways::SchedulerWeatherFarmListGateway;
use crate::internal_jobs::ports::SchedulerWeatherFetchSchedulePort;
use crate::shared::ports::ClockPort;
use crate::weather_data::gateways::StartFarmWeatherDataFetchPort;
use crate::weather_data::policies::GapFillWeatherFetchWindowPolicy;

/// Ruby: `UpdateReferenceWeatherDataJob` + `UpdateUserFarmsWeatherDataJob` enqueue logic.
pub struct SchedulerWeatherBatchEnqueueInteractor<'a> {
    list_gateway: &'a dyn SchedulerWeatherFarmListGateway,
    schedule_port: &'a dyn SchedulerWeatherFetchSchedulePort,
    start_weather_fetch: &'a dyn StartFarmWeatherDataFetchPort,
    clock: &'a dyn ClockPort,
}

impl<'a> SchedulerWeatherBatchEnqueueInteractor<'a> {
    pub fn new(
        list_gateway: &'a dyn SchedulerWeatherFarmListGateway,
        schedule_port: &'a dyn SchedulerWeatherFetchSchedulePort,
        start_weather_fetch: &'a dyn StartFarmWeatherDataFetchPort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            list_gateway,
            schedule_port,
            start_weather_fetch,
            clock,
        }
    }

    pub fn call(&self) -> Result<(), String> {
        let pending_farm_ids = self
            .list_gateway
            .list_user_farms_pending_initial_weather_fetch()?;
        let as_of = self.clock.today();
        for farm_id in pending_farm_ids {
            self.start_weather_fetch.call(farm_id, as_of);
        }

        let reference_farms = self.list_gateway.list_reference_farms_for_weather_update()?;
        self.schedule_gap_fill_farms(&reference_farms, 0);

        let user_farms = self.list_gateway.list_user_farms_for_weather_update()?;
        self.schedule_gap_fill_farms(&user_farms, 0);

        self.schedule_port.flush();
        Ok(())
    }

    fn schedule_gap_fill_farms(&self, farms: &[SchedulerWeatherFarmRow], delay_offset: u64) {
        for (index, farm) in farms.iter().enumerate() {
            let Some(range) =
                GapFillWeatherFetchWindowPolicy::fetch_range(farm.latest_weather_date, self.clock)
            else {
                continue;
            };
            self.schedule_port.schedule_fetch(
                farm.farm_id,
                farm.latitude,
                farm.longitude,
                range.start_date,
                range.end_date,
                delay_offset + index as u64,
            );
        }
    }
}

#[cfg(test)]
mod interactors_scheduler_weather_batch_enqueue_interactor_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/internal_jobs/interactors_scheduler_weather_batch_enqueue_interactor_test.rs"
    ));
}
