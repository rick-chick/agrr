//! Ruby: `Domain::FileBlob::Dtos::FileBlobPurgeOutput`

/// Ruby: `Domain::FileBlob::Dtos::FileBlobPurgeOutput`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FileBlobPurgeOutput {
    pub purged: bool,
}

impl FileBlobPurgeOutput {
    pub fn new(purged: bool) -> Self {
        Self { purged }
    }

    pub fn purged(&self) -> bool {
        self.purged
    }
}
