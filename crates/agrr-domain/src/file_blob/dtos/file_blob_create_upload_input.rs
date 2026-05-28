//! Ruby: `Domain::FileBlob::Dtos::FileBlobCreateUploadInput`

/// Upload payload at the use-case boundary (`upload` implements `#read` in Ruby).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileBlobCreateUploadInput {
    pub upload: Option<Vec<u8>>,
    pub filename: String,
    pub content_type: String,
}

impl FileBlobCreateUploadInput {
    pub fn new(
        upload: Option<Vec<u8>>,
        filename: impl Into<String>,
        content_type: impl Into<String>,
    ) -> Self {
        Self {
            upload,
            filename: filename.into(),
            content_type: content_type.into(),
        }
    }

    pub fn upload_blank(&self) -> bool {
        self.upload
            .as_ref()
            .map(|bytes| bytes.is_empty())
            .unwrap_or(true)
    }
}
