import { of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { ApiService } from '../../services/api.service';
import { WorkRecordPhotoApiGateway } from './work-record-photo-api.gateway';

describe('WorkRecordPhotoApiGateway', () => {
  it('calls upload_init, content PUT, and upload_complete in order', () => {
    const post = vi.fn((path: string, body: unknown) => {
      if (path.endsWith('/upload_init')) {
        return of({
          photo: {
            id: 7,
            upload_url: '/api/v1/plans/1/work_records/2/photos/7/content',
            upload_method: 'PUT',
            upload_expires_at: '2026-06-12T00:10:00Z',
            content_type: 'image/jpeg'
          }
        });
      }
      return of({
        photo: {
          id: 7,
          work_record_id: 2,
          position: 0,
          content_type: 'image/jpeg',
          byte_size: 3,
          url: '/api/v1/plans/1/work_records/2/photos/7/content',
          created_at: '2026-06-12T00:00:00Z'
        }
      });
    });
    const putBytes = vi.fn(() => of(undefined));
    const apiClient = { post, putBytes, delete: vi.fn(() => of(null)) } as unknown as ApiService;

    const gateway = new WorkRecordPhotoApiGateway(apiClient);
    const blob = new Blob([new Uint8Array([1, 2, 3])], { type: 'image/jpeg' });

    gateway.uploadInit(1, 2, 'image/jpeg').subscribe();
    expect(post).toHaveBeenCalledWith(
      '/api/v1/plans/1/work_records/2/photos/upload_init',
      { photo: { content_type: 'image/jpeg' } }
    );

    gateway
      .uploadContent('/api/v1/plans/1/work_records/2/photos/7/content', blob, 'image/jpeg')
      .subscribe();
    expect(putBytes).toHaveBeenCalledWith(
      '/api/v1/plans/1/work_records/2/photos/7/content',
      blob,
      'image/jpeg'
    );

    gateway.uploadComplete(1, 2, 7, 3).subscribe();
    expect(post).toHaveBeenCalledWith(
      '/api/v1/plans/1/work_records/2/photos/7/upload_complete',
      { photo: { byte_size: 3 } }
    );
  });
});
