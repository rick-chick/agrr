import {
  MAX_WORK_RECORD_PHOTO_LONG_EDGE_PX,
  WORK_RECORD_PHOTO_JPEG_QUALITY
} from './work-record-photo.constants';

export async function resizeWorkRecordPhoto(file: File): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const longEdge = Math.max(bitmap.width, bitmap.height);
  const scale =
    longEdge > MAX_WORK_RECORD_PHOTO_LONG_EDGE_PX
      ? MAX_WORK_RECORD_PHOTO_LONG_EDGE_PX / longEdge
      : 1;
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) {
    bitmap.close();
    throw new Error('canvas_unavailable');
  }
  context.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  const blob = await new Promise<Blob | null>((resolve) => {
    canvas.toBlob(resolve, 'image/jpeg', WORK_RECORD_PHOTO_JPEG_QUALITY);
  });
  if (!blob) {
    throw new Error('resize_failed');
  }
  return blob;
}
