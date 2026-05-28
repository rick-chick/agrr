//! Ruby: file blob create presenter callbacks

use crate::file_blob::dtos::FileBlobRow;

pub trait FileBlobCreateOutputPort {
    fn on_missing_file(&mut self);
    fn on_created(&mut self, row: &FileBlobRow);
}
