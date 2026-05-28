//! Add/remove field REST output ports.

pub trait AddFieldOutputPort {
    fn on_success(&mut self, field_id: i64, name: &str, area: f64, total_area: f64);
    fn on_not_found(&mut self);
    fn on_invalid_field_params(&mut self);
    fn on_max_fields_limit(&mut self);
    fn on_record_invalid(&mut self, message: &str);
    fn on_unexpected(&mut self, message: &str);
}

pub trait RemoveFieldOutputPort {
    fn on_success(&mut self, field_id: i64, total_area: f64);
    fn on_not_found(&mut self);
    fn on_field_not_found(&mut self);
    fn on_cannot_remove_with_cultivations(&mut self);
    fn on_cannot_remove_last_field(&mut self);
    fn on_record_invalid(&mut self, message: &str);
    fn on_unexpected(&mut self, message: &str);
}
