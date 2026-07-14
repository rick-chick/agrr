import { WorkRecordPhoto } from '../../models/plans/work-record-photo';

const MAX_LIST_THUMBNAILS = 3;

export function previewWorkRecordPhotos(photos: WorkRecordPhoto[] | undefined): WorkRecordPhoto[] {
  if (!photos?.length) return [];
  return [...photos].sort((a, b) => a.position - b.position).slice(0, MAX_LIST_THUMBNAILS);
}

export function sortedWorkRecordPhotos(photos: WorkRecordPhoto[] | undefined): WorkRecordPhoto[] {
  if (!photos?.length) return [];
  return [...photos].sort((a, b) => a.position - b.position);
}
