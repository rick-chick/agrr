pub trait MastersCropPestsDestroyOutputPort {
    fn on_success(&mut self);
    fn on_crop_not_found(&mut self);
    fn on_pest_not_found(&mut self);
    fn on_not_associated(&mut self);
}
