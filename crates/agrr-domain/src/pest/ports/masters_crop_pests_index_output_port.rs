use crate::pest::entities::PestEntity;

pub trait MastersCropPestsIndexOutputPort {
    fn on_success(&mut self, pests: Vec<PestEntity>);
}
