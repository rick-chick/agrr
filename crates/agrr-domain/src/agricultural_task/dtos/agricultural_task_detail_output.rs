use crate::agricultural_task::entities::AgriculturalTaskEntity;

/// Gateway payload before authorization enrichment.
#[derive(Debug, Clone)]
pub struct AgriculturalTaskShowDetail {
    pub task: AgriculturalTaskEntity,
    pub associated_crops: Vec<AssociatedCrop>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AssociatedCrop {
    pub id: i64,
    pub name: String,
}

/// Ruby: `Domain::AgriculturalTask::Dtos::AgriculturalTaskDetailOutput`
#[derive(Debug, Clone)]
pub struct AgriculturalTaskDetailOutput {
    pub task: AgriculturalTaskEntity,
    pub associated_crops: Vec<AssociatedCrop>,
}

impl AgriculturalTaskDetailOutput {
    pub fn new(task: AgriculturalTaskEntity, associated_crops: Vec<AssociatedCrop>) -> Self {
        Self {
            task,
            associated_crops,
        }
    }

    pub fn crops(&self) -> &[AssociatedCrop] {
        &self.associated_crops
    }
}

impl From<AgriculturalTaskShowDetail> for AgriculturalTaskDetailOutput {
    fn from(detail: AgriculturalTaskShowDetail) -> Self {
        Self::new(detail.task, detail.associated_crops)
    }
}
