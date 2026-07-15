//! Ruby: `Domain::Crop::Interactors::CropStageReorderInteractor`

use crate::crop::dtos::{CropStageListOutput, CropStageReorderInput};
use crate::crop::gateways::CropStageReorderGateway;
use crate::crop::ports::{CropStageReorderFailure, CropStageReorderOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};

pub struct CropStageReorderInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> CropStageReorderInteractor<'a, G, O>
where
    G: CropStageReorderGateway,
    O: CropStageReorderOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self { output_port, gateway }
    }

    pub fn call(
        &mut self,
        input: CropStageReorderInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if input.orders.is_empty() {
            self.output_port.on_failure(CropStageReorderFailure::Error(Error::new(
                "orders cannot be empty",
            )));
            return Ok(());
        }

        let mut seen_ids = std::collections::HashSet::new();
        let mut seen_orders = std::collections::HashSet::new();
        for entry in &input.orders {
            if !seen_ids.insert(entry.stage_id) {
                self.output_port.on_failure(CropStageReorderFailure::Error(Error::new(
                    "duplicate stage id",
                )));
                return Ok(());
            }
            if entry.order < 1 {
                self.output_port.on_failure(CropStageReorderFailure::Error(Error::new(
                    "order must be positive",
                )));
                return Ok(());
            }
            if !seen_orders.insert(entry.order) {
                self.output_port.on_failure(CropStageReorderFailure::Error(Error::new(
                    "duplicate order",
                )));
                return Ok(());
            }
        }

        let pairs: Vec<(i64, i64)> = input
            .orders
            .iter()
            .map(|entry| (entry.stage_id, entry.order))
            .collect();

        match self.gateway.reorder_crop_stages(input.crop_id, &pairs) {
            Ok(stages) => {
                self.output_port
                    .on_success(CropStageListOutput { stages });
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CropStageReorderFailure::Error(Error::new(
                        record_invalid.to_string(),
                    )));
                    Ok(())
                }
                Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                    self.output_port.on_failure(CropStageReorderFailure::NotFound);
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_stage_reorder_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_stage_reorder_interactor_test.rs"
    ));
}
