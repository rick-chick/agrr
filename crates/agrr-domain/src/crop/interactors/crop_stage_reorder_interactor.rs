//! Ruby: `Domain::Crop::Interactors::CropStageReorderInteractor`

use crate::crop::dtos::{CropStageListOutput, CropStageReorderInput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropStageReorderFailure, CropStageReorderOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use std::collections::HashSet;

pub struct CropStageReorderInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> CropStageReorderInteractor<'a, G, O>
where
    G: CropGateway,
    O: CropStageReorderOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self { output_port, gateway }
    }

    pub fn call(
        &mut self,
        input: CropStageReorderInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Err(message) = validate_reorder_input(&input) {
            self.output_port
                .on_failure(CropStageReorderFailure::Error(Error::new(message)));
            return Ok(());
        }

        let stage_orders: Vec<(i64, i64)> = input
            .entries
            .iter()
            .map(|entry| (entry.crop_stage_id, entry.order))
            .collect();

        match self
            .gateway
            .reorder_crop_stages(input.crop_id, stage_orders)
        {
            Ok(stages) => {
                self.output_port
                    .on_success(CropStageListOutput { stages });
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CropStageReorderFailure::Error(
                        Error::new(record_invalid.to_string()),
                    ));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

fn validate_reorder_input(input: &CropStageReorderInput) -> Result<(), String> {
    if input.entries.is_empty() {
        return Err("Invalid parameters".into());
    }

    let mut orders = HashSet::new();
    for entry in &input.entries {
        if entry.order <= 0 {
            return Err("Invalid parameters".into());
        }
        if !orders.insert(entry.order) {
            return Err("Invalid parameters".into());
        }
    }

    Ok(())
}

#[cfg(test)]
mod interactors_crop_stage_reorder_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_stage_reorder_interactor_test.rs"
    ));
}
