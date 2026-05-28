//! Ruby: file blob list presenter callbacks

use crate::file_blob::dtos::FileBlobRow;

pub trait FileBlobListOutputPort {
    fn on_list_success(&mut self, rows: &[FileBlobRow]);
}
