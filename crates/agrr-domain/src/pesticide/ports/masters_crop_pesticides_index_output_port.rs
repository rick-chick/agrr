use crate::pesticide::entities::PesticideEntity;

pub trait MastersCropPesticidesIndexOutputPort {
    fn on_success(&mut self, pesticides: Vec<PesticideEntity>);
    fn on_not_found(&mut self);
}
