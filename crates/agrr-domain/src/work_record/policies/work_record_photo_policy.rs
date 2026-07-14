//! Limits for work record photo attachments.

pub const MAX_PHOTOS_PER_RECORD: i32 = 3;
pub const MAX_BYTE_SIZE: i64 = 5 * 1024 * 1024;
pub const UPLOAD_URL_TTL_SECS: i64 = 600;
pub const READ_URL_TTL_SECS: i64 = 900;
/// Pending uploads older than this are removed from metadata (and best-effort object delete).
pub const PENDING_UPLOAD_CLEANUP_TTL_SECS: i64 = UPLOAD_URL_TTL_SECS * 2;

const ALLOWED_CONTENT_TYPES: &[&str] = &["image/jpeg", "image/png", "image/webp"];

pub fn photo_limit_exceeded(existing_count: i32) -> bool {
    existing_count >= MAX_PHOTOS_PER_RECORD
}

pub fn content_type_allowed(content_type: &str) -> bool {
    let normalized = content_type.trim().to_ascii_lowercase();
    ALLOWED_CONTENT_TYPES
        .iter()
        .any(|allowed| normalized == *allowed)
}

pub fn byte_size_allowed(byte_size: i64) -> bool {
    byte_size > 0 && byte_size <= MAX_BYTE_SIZE
}

pub fn extension_for_content_type(content_type: &str) -> &'static str {
    match content_type.trim().to_ascii_lowercase().as_str() {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    }
}

#[cfg(test)]
mod policies_work_record_photo_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/policies_work_record_photo_policy_test.rs"
    ));
}
