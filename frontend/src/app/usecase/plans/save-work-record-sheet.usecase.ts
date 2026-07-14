import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { concatMap, forkJoin, from, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_PHOTO_RESIZER } from '../../domain/plans/work-record-photo-resizer.token';
import { WorkRecord } from '../../models/plans/work-record';
import {
  WORK_RECORD_PHOTO_GATEWAY,
  WorkRecordPhotoGateway
} from './work-record-photo-gateway';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { SaveWorkRecordSheetInputDto } from './save-work-record-sheet.dtos';
import { SaveWorkRecordSheetInputPort } from './save-work-record-sheet.input-port';
import {
  SAVE_WORK_RECORD_SHEET_OUTPUT_PORT,
  SaveWorkRecordSheetOutputPort
} from './save-work-record-sheet.output-port';

type ValidationErrorBody = {
  errors?: Record<string, string[]>;
};

@Injectable()
export class SaveWorkRecordSheetUseCase implements SaveWorkRecordSheetInputPort {
  constructor(
    @Inject(SAVE_WORK_RECORD_SHEET_OUTPUT_PORT)
    private readonly outputPort: SaveWorkRecordSheetOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly workRecordGateway: WorkRecordGateway,
    @Inject(WORK_RECORD_PHOTO_GATEWAY) private readonly photoGateway: WorkRecordPhotoGateway,
    @Inject(WORK_RECORD_PHOTO_RESIZER) private readonly resizePhoto: (file: File) => Promise<Blob>
  ) {}

  execute(dto: SaveWorkRecordSheetInputDto): void {
    const save$ =
      dto.mode === 'edit' && dto.workRecordId != null
        ? this.workRecordGateway
            .updateWorkRecord(dto.planId, dto.workRecordId, dto.updateBody!)
            .pipe(map((response) => response.work_record))
        : this.workRecordGateway
            .createWorkRecord(dto.planId, dto.createBody!)
            .pipe(map((response) => response.work_record));

    save$
      .pipe(
        switchMap((workRecord) =>
          this.syncPhotos(dto, workRecord).pipe(map(() => workRecord))
        ),
        catchError((err: unknown) => {
          if (err instanceof HttpErrorResponse && err.status === 422) {
            const body = err.error as ValidationErrorBody | null;
            if (body?.errors && Object.keys(body.errors).length > 0) {
              this.outputPort.onValidationError({ fieldErrors: body.errors });
              return of(null);
            }
          }
          this.outputPort.onError({ message: apiErrorI18nKey(err) });
          return of(null);
        })
      )
      .subscribe((workRecord) => {
        if (workRecord) {
          this.outputPort.onSuccess({ workRecord, mode: dto.mode });
        }
      });
  }

  private syncPhotos(dto: SaveWorkRecordSheetInputDto, workRecord: WorkRecord) {
    const delete$ =
      dto.photoIdsToDelete.length === 0
        ? of(null)
        : forkJoin(
            dto.photoIdsToDelete.map((photoId) =>
              this.photoGateway.deletePhoto(dto.planId, workRecord.id, photoId)
            )
          );

    return delete$.pipe(
      switchMap(() => {
        if (dto.pendingPhotoFiles.length === 0) {
          return of(null);
        }
        return from(dto.pendingPhotoFiles).pipe(
          concatMap((file) =>
            from(this.resizePhoto(file)).pipe(
              switchMap((blob) => this.uploadBlob(dto.planId, workRecord.id, blob))
            )
          )
        );
      })
    );
  }

  private uploadBlob(planId: number, workRecordId: number, blob: Blob) {
    const contentType = 'image/jpeg';
    return this.photoGateway.uploadInit(planId, workRecordId, contentType).pipe(
      switchMap((init) =>
        this.photoGateway
          .uploadContent(init.photo.upload_url, blob, init.photo.content_type)
          .pipe(
            switchMap(() =>
              this.photoGateway.uploadComplete(
                planId,
                workRecordId,
                init.photo.id,
                blob.size
              )
            )
          )
      )
    );
  }
}
