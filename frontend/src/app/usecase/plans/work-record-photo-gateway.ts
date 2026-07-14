import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import {
  WorkRecordPhotoCompleteResponse,
  WorkRecordPhotoUploadInitResponse
} from '../../models/plans/work-record-photo';

export interface WorkRecordPhotoGateway {
  uploadInit(
    planId: number,
    recordId: number,
    contentType: string
  ): Observable<WorkRecordPhotoUploadInitResponse>;
  uploadContent(uploadUrl: string, body: Blob, contentType: string): Observable<void>;
  uploadComplete(
    planId: number,
    recordId: number,
    photoId: number,
    byteSize: number
  ): Observable<WorkRecordPhotoCompleteResponse>;
  deletePhoto(planId: number, recordId: number, photoId: number): Observable<void>;
}

export const WORK_RECORD_PHOTO_GATEWAY = new InjectionToken<WorkRecordPhotoGateway>(
  'WORK_RECORD_PHOTO_GATEWAY'
);
