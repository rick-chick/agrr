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

describe('SaveWorkRecordSheetUseCase', () => {
  it('creates record then uploads pending photos before success', async () => {
    const onSuccess = vi.fn();
    const outputPort: SaveWorkRecordSheetOutputPort = {
      onSuccess,
      onValidationError: vi.fn(),
      onError: vi.fn()
    };

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

    const photoGateway: WorkRecordPhotoGateway = {
      uploadInit,
      uploadContent,
      uploadComplete,
      deletePhoto: vi.fn(() => of(undefined))
    };

    const createWorkRecord = vi.fn(() => of({ work_record: sampleRecord }));
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord,
      updateWorkRecord: vi.fn(),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn()
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
      photoIdsToDelete: []
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
    const photoGateway: WorkRecordPhotoGateway = {
      uploadInit: vi.fn(),
      uploadContent: vi.fn(),
      uploadComplete: vi.fn(),
      deletePhoto
    };
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord: vi.fn(),
      updateWorkRecord: vi.fn(() => of({ work_record: sampleRecord })),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn()
    };
    const outputPort: SaveWorkRecordSheetOutputPort = {
      onSuccess: vi.fn(),
      onValidationError: vi.fn(),
      onError: vi.fn()
    };

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
      updateBody: { name: '除草' },
      pendingPhotoFiles: [],
      photoIdsToDelete: [55, 56]
    });

    await vi.waitFor(() => {
      expect(deletePhoto).toHaveBeenCalledTimes(2);
      expect(deletePhoto).toHaveBeenCalledWith(5, 9, 55);
      expect(deletePhoto).toHaveBeenCalledWith(5, 9, 56);
    });
  });

  it('maps upload failures to onError', async () => {
    const outputPort: SaveWorkRecordSheetOutputPort = {
      onSuccess: vi.fn(),
      onValidationError: vi.fn(),
      onError: vi.fn()
    };
    const photoGateway: WorkRecordPhotoGateway = {
      uploadInit: vi.fn(() => throwError(() => new Error('upload failed'))),
      uploadContent: vi.fn(),
      uploadComplete: vi.fn(),
      deletePhoto: vi.fn()
    };
    const workRecordGateway: WorkRecordGateway = {
      listWorkRecords: vi.fn(),
      createWorkRecord: vi.fn(() => of({ work_record: sampleRecord })),
      updateWorkRecord: vi.fn(),
      deleteWorkRecord: vi.fn(),
      skipTaskScheduleItem: vi.fn(),
      unskipTaskScheduleItem: vi.fn()
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
      photoIdsToDelete: []
    });

    await vi.waitFor(() => {
      expect(outputPort.onError).toHaveBeenCalled();
    });
  });
});
