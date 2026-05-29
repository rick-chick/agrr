//! Ruby: `Domain::Farm::Interactors::FarmListReferenceForRegionInteractor`

use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::FarmListReferenceForRegionOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::logger_port::LoggerPort;

pub struct FarmListReferenceForRegionInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    logger: &'a L,
}

impl<'a, G, O, L> FarmListReferenceForRegionInteractor<'a, G, O, L>
where
    G: FarmGateway,
    O: FarmListReferenceForRegionOutputPort,
    L: LoggerPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, logger: &'a L) -> Self {
        Self {
            output_port,
            gateway,
            logger,
        }
    }

    pub fn call(
        &mut self,
        region: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.list_reference_farms_for_region(region) {
            Ok(farms) => {
                self.output_port.on_success(farms);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    let message = record_invalid
                        .detail_message()
                        .unwrap_or("record invalid")
                        .to_string();
                    self.logger.error(&format!(
                        "[FarmListReferenceForRegionInteractor] {message}"
                    ));
                    self.output_port.on_failure(Error::new(message));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_farm_list_reference_for_region_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_list_reference_for_region_interactor_test.rs"));
}
