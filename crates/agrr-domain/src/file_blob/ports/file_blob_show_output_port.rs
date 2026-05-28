//! Ruby: file blob show presenter callbacks

use crate::file_blob::dtos::FileBlobRow;

pub trait FileBlobShowOutputPort {
    fn on_not_found(&mut self);
    fn on_show_success(&mut self, row: &FileBlobRow);
}
