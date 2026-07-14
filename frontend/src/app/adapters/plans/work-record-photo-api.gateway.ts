import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  WorkRecordPhotoCompleteResponse,
  WorkRecordPhotoUploadInitResponse
} from '../../models/plans/work-record-photo';
import { ApiService } from '../../services/api.service';
import { WorkRecordPhotoGateway } from '../../usecase/plans/work-record-photo-gateway';

@Injectable()
export class WorkRecordPhotoApiGateway implements WorkRecordPhotoGateway {
  constructor(private readonly apiClient: ApiService) {}

  uploadInit(
    planId: number,
    recordId: number,
    contentType: string
  ): Observable<WorkRecordPhotoUploadInitResponse> {
    return this.apiClient.post<WorkRecordPhotoUploadInitResponse>(
      `/api/v1/plans/${planId}/work_records/${recordId}/photos/upload_init`,
      { photo: { content_type: contentType } }
    );
  }

  uploadContent(uploadUrl: string, body: Blob, contentType: string): Observable<void> {
    return this.apiClient.putBytes(uploadUrl, body, contentType);
  }

  uploadComplete(
    planId: number,
    recordId: number,
    photoId: number,
    byteSize: number
  ): Observable<WorkRecordPhotoCompleteResponse> {
    return this.apiClient.post<WorkRecordPhotoCompleteResponse>(
      `/api/v1/plans/${planId}/work_records/${recordId}/photos/${photoId}/upload_complete`,
      { photo: { byte_size: byteSize } }
    );
  }

  deletePhoto(planId: number, recordId: number, photoId: number): Observable<void> {
    return this.apiClient
      .delete<void>(`/api/v1/plans/${planId}/work_records/${recordId}/photos/${photoId}`)
      .pipe(map(() => undefined));
  }
}
