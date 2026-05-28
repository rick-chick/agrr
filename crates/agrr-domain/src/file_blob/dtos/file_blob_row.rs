//! Ruby: `Domain::FileBlob::Dtos::FileBlobRow`

/// Ruby: `Domain::FileBlob::Dtos::FileBlobRow`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileBlobRow {
    pub id: i64,
    pub filename: String,
    pub content_type: String,
    pub byte_size: i64,
    pub created_at: String,
    pub url: String,
}

impl FileBlobRow {
    pub fn new(
        id: i64,
        filename: impl Into<String>,
        content_type: impl Into<String>,
        byte_size: i64,
        created_at: impl Into<String>,
        url: impl Into<String>,
    ) -> Self {
        Self {
            id,
            filename: filename.into(),
            content_type: content_type.into(),
            byte_size,
            created_at: created_at.into(),
            url: url.into(),
        }
    }
}
