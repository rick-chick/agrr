//! Input port for regenerating crop task schedule blueprints via AI.

use crate::crop::dtos::{
    CropBlueprintRegenerateFailure, CropRegenerateTaskScheduleBlueprintsInput,
    MastersCropTaskScheduleBlueprint,
};

pub trait CropRegenerateTaskScheduleBlueprintsInputPort: Send + Sync {
    fn call(
        &self,
        input: CropRegenerateTaskScheduleBlueprintsInput,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, CropBlueprintRegenerateFailure>;
}
