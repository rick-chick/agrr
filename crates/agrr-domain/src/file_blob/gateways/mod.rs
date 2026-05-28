//! Ruby: `Domain::FileBlob::Gateways::FileBlobGateway`

use crate::file_blob::dtos::FileBlobRow;

/// Ruby: `Domain::FileBlob::Gateways::FileBlobGateway`
pub trait FileBlobGateway: Send + Sync {
    fn list_rows_ordered_desc(&self) -> Vec<FileBlobRow>;

    fn find_by_id(&self, blob_id: i64) -> Option<FileBlobRow>;

    fn create_from_upload(
        &self,
        io: &[u8],
        filename: &str,
        content_type: &str,
    ) -> FileBlobRow;

    fn purge(&self, blob_id: i64) -> bool;
}
