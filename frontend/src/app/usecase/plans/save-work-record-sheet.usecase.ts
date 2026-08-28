import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { concatMap, forkJoin, from, Observable, of, throwError } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { MAX_WORK_RECORD_PHOTOS } from '../../domain/plans/work-record-photo.constants';
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
          this.syncPhotos(dto, workRecord).pipe(
            catchError((err: unknown) => this.handlePhotoSyncError(dto, workRecord, err, []))
          )
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

  private syncPhotos(
    dto: SaveWorkRecordSheetInputDto,
    workRecord: WorkRecord
  ): Observable<WorkRecord | null> {
    if (dto.pendingPhotoFiles.length === 0 && dto.photoIdsToDelete.length === 0) {
      return of(workRecord);
    }

    const uploadFirst = this.shouldUploadBeforeDelete(workRecord, dto);

    if (uploadFirst) {
      return this.uploadPending(dto, workRecord.id).pipe(
        switchMap(() => this.deleteMarked(dto, workRecord.id)),
        map(() => workRecord),
        catchError((err: unknown) => this.handlePhotoSyncError(dto, workRecord, err, []))
      );
    }

    return this.syncPhotosWithCompensation(dto, workRecord);
  }

  private syncPhotosWithCompensation(
    dto: SaveWorkRecordSheetInputDto,
    workRecord: WorkRecord
  ): Observable<WorkRecord | null> {
    return this.fetchDeletedPhotoBackups(dto.deletedPhotoContentUrls).pipe(
      switchMap((backups) =>
        this.deleteMarked(dto, workRecord.id).pipe(
          switchMap(() => this.uploadPending(dto, workRecord.id)),
          map(() => workRecord),
          catchError((err: unknown) => this.handlePhotoSyncError(dto, workRecord, err, backups))
        )
      )
    );
  }

  private fetchDeletedPhotoBackups(
    sources: SaveWorkRecordSheetInputDto['deletedPhotoContentUrls']
  ): Observable<Array<{ photoId: number; blob: Blob }>> {
    if (sources.length === 0) {
      return of([]);
    }

    return forkJoin(
      sources.map((source) =>
        this.photoGateway.downloadPhotoContent(source.contentUrl).pipe(
          map((blob) => ({ photoId: source.photoId, blob }))
        )
      )
    );
  }

  private shouldUploadBeforeDelete(
    workRecord: WorkRecord,
    dto: SaveWorkRecordSheetInputDto
  ): boolean {
    if (dto.pendingPhotoFiles.length === 0) {
      return false;
    }
    if (dto.photoIdsToDelete.length === 0) {
      return true;
    }

    const serverPhotoCount = workRecord.photos?.length ?? 0;
    return serverPhotoCount + dto.pendingPhotoFiles.length <= MAX_WORK_RECORD_PHOTOS;
  }

  private handlePhotoSyncError(
    dto: SaveWorkRecordSheetInputDto,
    workRecord: WorkRecord,
    err: unknown,
    backups: Array<{ photoId: number; blob: Blob }>
  ): Observable<WorkRecord | null> {
    const uploadFirst = this.shouldUploadBeforeDelete(workRecord, dto);
    const needsCompensation = !uploadFirst && backups.length > 0;
    const needsPartialFailure =
      needsCompensation ||
      (uploadFirst && dto.photoIdsToDelete.length > 0 && dto.pendingPhotoFiles.length > 0);

    if (!needsPartialFailure) {
      this.outputPort.onError({ message: apiErrorI18nKey(err) });
      return of(null);
    }

    const compensate$ =
      needsCompensation
        ? forkJoin(
            backups.map((backup) =>
              this.uploadBlob(dto.planId, workRecord.id, backup.blob)
            )
          ).pipe(map(() => undefined))
        : of(undefined);

    return compensate$.pipe(
      switchMap(() => this.reloadWorkRecord(dto, workRecord.id)),
      map((reloaded) => {
        this.outputPort.onPhotoPartialFailure({ workRecord: reloaded });
        return null;
      }),
      catchError(() => {
        this.outputPort.onError({ message: apiErrorI18nKey(err) });
        return of(null);
      })
    );
  }

  private reloadWorkRecord(
    dto: SaveWorkRecordSheetInputDto,
    workRecordId: number
  ): Observable<WorkRecord> {
    return this.workRecordGateway.listWorkRecords(dto.planId).pipe(
      switchMap((response) => {
        const found = response.work_records.find((record) => record.id === workRecordId);
        if (!found) {
          return throwError(() => new Error('plans.work_records.errors.not_found'));
        }
        return of(found);
      })
    );
  }

  private deleteMarked(dto: SaveWorkRecordSheetInputDto, workRecordId: number): Observable<void> {
    if (dto.photoIdsToDelete.length === 0) {
      return of(undefined);
    }

    return forkJoin(
      dto.photoIdsToDelete.map((photoId) =>
        this.photoGateway.deletePhoto(dto.planId, workRecordId, photoId)
      )
    ).pipe(map(() => undefined));
  }

  private uploadPending(dto: SaveWorkRecordSheetInputDto, workRecordId: number): Observable<void> {
    if (dto.pendingPhotoFiles.length === 0) {
      return of(undefined);
    }

    return from(dto.pendingPhotoFiles).pipe(
      concatMap((file) =>
        from(this.resizePhoto(file)).pipe(
          switchMap((blob) => this.uploadBlob(dto.planId, workRecordId, blob))
        )
      ),
      map(() => undefined)
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
