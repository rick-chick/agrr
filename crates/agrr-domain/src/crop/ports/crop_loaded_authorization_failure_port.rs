pub trait CropLoadedAuthorizationFailurePort {
    fn on_permission_denied(&mut self);
    fn on_not_found(&mut self);
}
