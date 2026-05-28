//! Ruby: file blob destroy presenter callbacks

pub trait FileBlobDestroyOutputPort {
    fn on_not_found(&mut self);
    fn on_deleted(&mut self);
}
