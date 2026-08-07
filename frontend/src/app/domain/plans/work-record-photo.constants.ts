export const MAX_WORK_RECORD_PHOTOS = 3;
export const MAX_WORK_RECORD_PHOTO_LONG_EDGE_PX = 1920;
export const WORK_RECORD_PHOTO_JPEG_QUALITY = 0.85;

/** Landscape thumbnail aspect ratio (width / height). See ADR-work-record-photos.md §8.1 */
export const WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO = '4 / 3';
export const WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY = '4rem';
export const WORK_RECORD_PHOTO_THUMB_WIDTH_SHEET = '4.5rem';

/** Intrinsic img dimensions (4:3 at 16px/rem) for CLS suppression. See ADR-work-record-photos.md §8.1 */
export const WORK_RECORD_PHOTO_THUMB_WIDTH_PX_HISTORY = 64;
export const WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_HISTORY = 48;
export const WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET = 72;
export const WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET = 54;

export const WORK_RECORD_PHOTO_ACCEPT =
  'image/jpeg,image/png,image/webp';
