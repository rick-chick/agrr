import { InjectionToken } from '@angular/core';
import { resizeWorkRecordPhoto } from '../../domain/plans/resize-work-record-photo';

export type WorkRecordPhotoResizer = (file: File) => Promise<Blob>;

export const WORK_RECORD_PHOTO_RESIZER = new InjectionToken<WorkRecordPhotoResizer>(
  'WORK_RECORD_PHOTO_RESIZER',
  {
    providedIn: 'root',
    factory: () => resizeWorkRecordPhoto
  }
);
