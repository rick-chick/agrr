//! Ruby: `Domain::Crop::Interactors::CropListReferenceEntitiesInteractor`

use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::CropListReferenceEntitiesOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropListReferenceEntitiesInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> CropListReferenceEntitiesInteractor<'a, G, O>
where
    G: CropGateway,
    O: CropListReferenceEntitiesOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(
        &mut self,
        region: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.list_by_is_reference(true, region) {
            Ok(crops) => {
                self.output_port.on_success(crops);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    let message = record_invalid
                        .detail_message()
                        .unwrap_or("record invalid")
                        .to_string();
                    self.output_port.on_failure(Error::new(message));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_list_reference_entities_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_list_reference_entities_interactor_test.rs"));
}
