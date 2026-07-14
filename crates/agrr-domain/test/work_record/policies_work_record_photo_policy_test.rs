use crate::work_record::policies::work_record_photo_policy::{
    byte_size_allowed, content_type_allowed, extension_for_content_type, photo_limit_exceeded,
    MAX_BYTE_SIZE, MAX_PHOTOS_PER_RECORD,
};

#[test]
fn photo_limit_exceeded_at_three() {
    assert!(!photo_limit_exceeded(0));
    assert!(!photo_limit_exceeded(2));
    assert!(photo_limit_exceeded(MAX_PHOTOS_PER_RECORD));
}

#[test]
fn content_type_allowed_accepts_common_images() {
    assert!(content_type_allowed("image/jpeg"));
    assert!(content_type_allowed("image/png"));
    assert!(content_type_allowed("image/webp"));
    assert!(!content_type_allowed("image/heic"));
}

#[test]
fn byte_size_allowed_within_five_megabytes() {
    assert!(byte_size_allowed(1));
    assert!(byte_size_allowed(MAX_BYTE_SIZE));
    assert!(!byte_size_allowed(MAX_BYTE_SIZE + 1));
    assert!(!byte_size_allowed(0));
}

#[test]
fn extension_for_content_type_maps_mime() {
    assert_eq!(extension_for_content_type("image/png"), "png");
    assert_eq!(extension_for_content_type("image/webp"), "webp");
    assert_eq!(extension_for_content_type("image/jpeg"), "jpg");
}
