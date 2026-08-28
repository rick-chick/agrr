import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordGateway } from './work-record-gateway';
import { WorkRecordPhotoGateway } from './work-record-photo-gateway';
import { SaveWorkRecordSheetUseCase } from './save-work-record-sheet.usecase';
import { SaveWorkRecordSheetOutputPort } from './save-work-record-sheet.output-port';

const resizePhoto = async (file: File) => file;

const sampleRecord: WorkRecord = {
  id: 9,
  cultivation_plan_id: 5,
  field_cultivation_id: null,
  task_schedule_item_id: null,
  agricultural_task_id: null,
  name: '除草',
  task_type: null,
  actual_date: '2026-06-12',
  amount: null,
  amount_unit: null,
  time_spent_minutes: null,
  notes: null,
  created_at: '2026-06-12T00:00:00Z',
  updated_at: '2026-06-12T00:00:00Z',
  task_schedule_item: null,
  photos: []
};

function outputPortStub(): SaveWorkRecordSheetOutputPort {
  return {
    onSuccess: vi.fn(),
    onValidationError: vi.fn(),
    onPhotoPartialFailure: vi.fn(),
    onError: vi.fn()
  };
}

function photoGatewayStub(overrides: Partial<WorkRecordPhotoGateway> = {}): WorkRecordPhotoGateway {
  return {
    uploadInit: vi.fn(),
    uploadContent: vi.fn(),
    uploadComplete: vi.fn(),
    deletePhoto: vi.fn(() => of(undefined)),
    downloadPhotoContent: vi.fn(),
    ...overrides
  };
}

describe('SaveWorkRecordSheetUseCase', () => {
  it('creates record then uploads pending photos before success', async () => {
    const outputPort = outputPortStub();
    const onSuccess = outputPort.onSuccess as ReturnType<typeof vi.fn>;

    const uploadInit = vi.fn(() =>
      of({
        photo: {
          id: 101,
          upload_url: '/api/v1/plans/5/work_records/9/photos/101/content',
          upload_method: 'PUT',
          upload_expires_at: '2026-06-12T00:10:00Z',
          content_type: 'image/jpeg'
        }
      })
    );
    const uploadContent = vi.fn(() => of(undefined));
    const uploadComplete = vi.fn(() =>
      of({
        photo: {
          id: 101,
          work_record_id: 9,
          position: 0,
          content_type: 'image/jpeg',
          byte_size: 4,
          url: '/api/v1/plans/5/work_records/9/photos/101/content',
          created_at: '2026-06-12T00:00:00Z'
        }
      })
    );

    const photoGateway = photoGatewayStub({
      uploadInit,
      uploadContent,
      uploadComplete
    });

    const createWorkRecord = vi.fn(() => of({ work_record: sampleRecord }));
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord,
      updateWorkRecord: vi.fn(),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn(),
      updateTaskScheduleItem: () => of({} as never),
    };

    const file = new File([new Uint8Array([1, 2, 3, 4])], 'field.jpg', {
      type: 'image/jpeg'
    });

    const useCase = new SaveWorkRecordSheetUseCase(
      outputPort,
      workRecordGateway,
      photoGateway,
      resizePhoto
    );
    useCase.execute({
      planId: 5,
      mode: 'create-adhoc',
      createBody: { name: '除草', actual_date: '2026-06-12' },
      pendingPhotoFiles: [file],
      photoIdsToDelete: [],
      deletedPhotoContentUrls: []
    });

    await vi.waitFor(() => {
      expect(createWorkRecord).toHaveBeenCalled();
      expect(uploadInit).toHaveBeenCalledWith(5, 9, 'image/jpeg');
      expect(uploadContent).toHaveBeenCalled();
      expect(uploadComplete).toHaveBeenCalledWith(5, 9, 101, 4);
      expect(onSuccess).toHaveBeenCalledWith({ workRecord: sampleRecord, mode: 'create-adhoc' });
    });
  });

  it('deletes marked photos on edit before uploading', async () => {
    const deletePhoto = vi.fn(() => of(undefined));
    const photoGateway = photoGatewayStub({ deletePhoto });
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord: vi.fn(),
      updateWorkRecord: vi.fn(() => of({ work_record: sampleRecord })),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn(),
      updateTaskScheduleItem: () => of({} as never),
    };
    const outputPort = outputPortStub();

    const useCase = new SaveWorkRecordSheetUseCase(
      outputPort,
      workRecordGateway,
      photoGateway,
      resizePhoto
    );
    useCase.execute({
      planId: 5,
      mode: 'edit',
      workRecordId: 9,
      updateBody: { updated_at: '2026-06-12T00:00:00Z', name: '除草' },
      pendingPhotoFiles: [],
      photoIdsToDelete: [55, 56],
      deletedPhotoContentUrls: []
    });

    await vi.waitFor(() => {
      expect(deletePhoto).toHaveBeenCalledTimes(2);
      expect(deletePhoto).toHaveBeenCalledWith(5, 9, 55);
      expect(deletePhoto).toHaveBeenCalledWith(5, 9, 56);
    });
  });

  it('maps upload failures to onError', async () => {
    const outputPort = outputPortStub();
    const photoGateway = photoGatewayStub({
      uploadInit: vi.fn(() => throwError(() => new Error('upload failed')))
    });
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord: vi.fn(() => of({ work_record: sampleRecord })),
      updateWorkRecord: vi.fn(),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn(),
      updateTaskScheduleItem: () => of({} as never),
    };

    const useCase = new SaveWorkRecordSheetUseCase(
      outputPort,
      workRecordGateway,
      photoGateway,
      resizePhoto
    );
    useCase.execute({
      planId: 5,
      mode: 'create-adhoc',
      createBody: { name: '除草', actual_date: '2026-06-12' },
      pendingPhotoFiles: [
        new File([new Uint8Array([1])], 'a.jpg', { type: 'image/jpeg' })
      ],
      photoIdsToDelete: [],
      deletedPhotoContentUrls: []
    });

    await vi.waitFor(() => {
      expect(outputPort.onError).toHaveBeenCalled();
    });
  });

  it('uploads before deletes when there is photo capacity', async () => {
    const callOrder: string[] = [];
    const recordWithPhoto: WorkRecord = {
      ...sampleRecord,
      photos: [
        {
          id: 55,
          work_record_id: 9,
          position: 0,
          content_type: 'image/jpeg',
          byte_size: 100,
          url: '/photos/55.jpg',
          created_at: '2026-06-12T00:00:00Z'
        }
      ]
    };
    const uploadInit = vi.fn(() => {
      callOrder.push('upload');
      return of({
        photo: {
          id: 101,
          upload_url: '/upload',
          upload_method: 'PUT',
          upload_expires_at: '2026-06-12T00:10:00Z',
          content_type: 'image/jpeg'
        }
      });
    });
    const deletePhoto = vi.fn(() => {
      callOrder.push('delete');
      return of(undefined);
    });
    const photoGateway = photoGatewayStub({
      uploadInit,
      uploadContent: vi.fn(() => of(undefined)),
      uploadComplete: vi.fn(() =>
        of({
          photo: {
            id: 101,
            work_record_id: 9,
            position: 1,
            content_type: 'image/jpeg',
            byte_size: 4,
            url: '/photos/101.jpg',
            created_at: '2026-06-12T00:00:00Z'
          }
        })
      ),
      deletePhoto
    });
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord: vi.fn(),
      updateWorkRecord: vi.fn(() => of({ work_record: recordWithPhoto })),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn(),
      updateTaskScheduleItem: () => of({} as never)
    };
    const outputPort = outputPortStub();
    const useCase = new SaveWorkRecordSheetUseCase(
      outputPort,
      workRecordGateway,
      photoGateway,
      resizePhoto
    );
    const file = new File([new Uint8Array([1, 2, 3, 4])], 'field.jpg', {
      type: 'image/jpeg'
    });

    useCase.execute({
      planId: 5,
      mode: 'edit',
      workRecordId: 9,
      updateBody: { name: '除草' },
      pendingPhotoFiles: [file],
      photoIdsToDelete: [55],
      deletedPhotoContentUrls: [{ photoId: 55, contentUrl: '/photos/55.jpg' }]
    });

    await vi.waitFor(() => {
      expect(callOrder).toEqual(['upload', 'delete']);
    });
  });

  it('compensates deleted photos and reports partial failure when upload fails at limit', async () => {
    const recordAtLimit: WorkRecord = {
      ...sampleRecord,
      photos: [
        {
          id: 1,
          work_record_id: 9,
          position: 0,
          content_type: 'image/jpeg',
          byte_size: 100,
          url: '/photos/1.jpg',
          created_at: '2026-06-12T00:00:00Z'
        },
        {
          id: 2,
          work_record_id: 9,
          position: 1,
          content_type: 'image/jpeg',
          byte_size: 100,
          url: '/photos/2.jpg',
          created_at: '2026-06-12T00:00:00Z'
        },
        {
          id: 3,
          work_record_id: 9,
          position: 2,
          content_type: 'image/jpeg',
          byte_size: 100,
          url: '/photos/3.jpg',
          created_at: '2026-06-12T00:00:00Z'
        }
      ]
    };
    const reloadedRecord: WorkRecord = {
      ...recordAtLimit,
      photos: recordAtLimit.photos!
    };
    let uploadAttempts = 0;
    const uploadInit = vi.fn(() => {
      uploadAttempts += 1;
      if (uploadAttempts === 1) {
        return throwError(() => new Error('upload failed'));
      }
      return of({
        photo: {
          id: 201,
          upload_url: '/upload',
          upload_method: 'PUT',
          upload_expires_at: '2026-06-12T00:10:00Z',
          content_type: 'image/jpeg'
        }
      });
    });
    const backupBlob = new Blob([new Uint8Array([9])], { type: 'image/jpeg' });
    const photoGateway = photoGatewayStub({
      downloadPhotoContent: vi.fn(() => of(backupBlob)),
      uploadInit,
      uploadContent: vi.fn(() => of(undefined)),
      uploadComplete: vi.fn(() =>
        of({
          photo: {
            id: 201,
            work_record_id: 9,
            position: 0,
            content_type: 'image/jpeg',
            byte_size: 4,
            url: '/photos/201.jpg',
            created_at: '2026-06-12T00:00:00Z'
          }
        })
      )
    });
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(() => of({ work_records: [reloadedRecord] })),
      createWorkRecord: vi.fn(),
      updateWorkRecord: vi.fn(() => of({ work_record: recordAtLimit })),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn(),
      updateTaskScheduleItem: () => of({} as never)
    };
    const outputPort = outputPortStub();
    const useCase = new SaveWorkRecordSheetUseCase(
      outputPort,
      workRecordGateway,
      photoGateway,
      resizePhoto
    );
    const file = new File([new Uint8Array([1])], 'new.jpg', { type: 'image/jpeg' });

    useCase.execute({
      planId: 5,
      mode: 'edit',
      workRecordId: 9,
      updateBody: { name: '除草' },
      pendingPhotoFiles: [file],
      photoIdsToDelete: [1, 2],
      deletedPhotoContentUrls: [
        { photoId: 1, contentUrl: '/photos/1.jpg' },
        { photoId: 2, contentUrl: '/photos/2.jpg' }
      ]
    });

    await vi.waitFor(() => {
      expect(photoGateway.deletePhoto).toHaveBeenCalledTimes(2);
      expect(photoGateway.downloadPhotoContent).toHaveBeenCalledTimes(2);
      expect(uploadInit).toHaveBeenCalledTimes(3);
      expect(outputPort.onPhotoPartialFailure).toHaveBeenCalledWith({
        workRecord: reloadedRecord
      });
    });
  });
});
