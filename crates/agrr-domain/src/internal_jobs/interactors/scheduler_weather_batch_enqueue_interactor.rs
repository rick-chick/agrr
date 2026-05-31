use crate::internal_jobs::gateways::SchedulerWeatherFarmListGateway;
use crate::internal_jobs::ports::SchedulerWeatherFetchSchedulePort;
use crate::shared::ports::ClockPort;
use crate::weather_data::policies::{
    SchedulerReferenceFarmFetchWindowPolicy, SchedulerUserFarmFetchWindowPolicy,
};

/// Ruby: `UpdateReferenceWeatherDataJob` + `UpdateUserFarmsWeatherDataJob` enqueue logic.
pub struct SchedulerWeatherBatchEnqueueInteractor<'a> {
    list_gateway: &'a dyn SchedulerWeatherFarmListGateway,
    schedule_port: &'a dyn SchedulerWeatherFetchSchedulePort,
    clock: &'a dyn ClockPort,
}

impl<'a> SchedulerWeatherBatchEnqueueInteractor<'a> {
    pub fn new(
        list_gateway: &'a dyn SchedulerWeatherFarmListGateway,
        schedule_port: &'a dyn SchedulerWeatherFetchSchedulePort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            list_gateway,
            schedule_port,
            clock,
        }
    }

    pub fn call(&self) -> Result<(), String> {
        if let Some(range) = SchedulerReferenceFarmFetchWindowPolicy::fetch_range(self.clock) {
            let farms = self.list_gateway.list_reference_farms_for_weather_update()?;
            for (index, farm) in farms.iter().enumerate() {
                self.schedule_port.schedule_fetch(
                    farm.farm_id,
                    farm.latitude,
                    farm.longitude,
                    range.start_date,
                    range.end_date,
                    index as u64,
                );
            }
        }

        let user_farms = self.list_gateway.list_user_farms_for_weather_update()?;
        for (index, farm) in user_farms.iter().enumerate() {
            let Some(range) =
                SchedulerUserFarmFetchWindowPolicy::fetch_range(farm.latest_weather_date, self.clock)
            else {
                continue;
            };
            self.schedule_port.schedule_fetch(
                farm.farm_id,
                farm.latitude,
                farm.longitude,
                range.start_date,
                range.end_date,
                index as u64,
            );
        }

        self.schedule_port.flush();
        Ok(())
    }
}

#[cfg(test)]
mod interactors_scheduler_weather_batch_enqueue_interactor_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/internal_jobs/interactors_scheduler_weather_batch_enqueue_interactor_test.rs"
    ));
}
