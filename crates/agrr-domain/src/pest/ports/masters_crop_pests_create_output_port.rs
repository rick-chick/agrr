pub trait MastersCropPestsCreateOutputPort {
    fn on_success(&mut self, crop_id: i64, pest_id: i64);
    fn on_pest_id_missing(&mut self);
    fn on_pest_not_found(&mut self);
    fn on_forbidden(&mut self);
    fn on_already_associated(&mut self);
}
