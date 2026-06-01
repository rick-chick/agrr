import { TestBed } from '@angular/core/testing';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { of, firstValueFrom } from 'rxjs';
import { TranslateService } from '@ngx-translate/core';
import { MastersClientService } from './masters-client.service';
import { ApiService } from '../api.service';
import { ApiKeyService } from '../api-key.service';

describe('MastersClientService', () => {
  let service: MastersClientService;
  let apiClient: { get: ReturnType<typeof vi.fn>; delete: ReturnType<typeof vi.fn> };
  let apiKeyService: { getApiKey: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    apiClient = { get: vi.fn().mockReturnValue(of({})), delete: vi.fn() };
    apiKeyService = { getApiKey: vi.fn().mockReturnValue(null) };

    await TestBed.configureTestingModule({
      providers: [
        MastersClientService,
        { provide: ApiService, useValue: apiClient },
        { provide: ApiKeyService, useValue: apiKeyService },
        {
          provide: TranslateService,
          useValue: { currentLang: 'in', defaultLang: 'ja' } satisfies Pick<
            TranslateService,
            'currentLang' | 'defaultLang'
          >
        }
      ]
    }).compileComponents();

    service = TestBed.inject(MastersClientService);
  });

  it('get uses /api/v1/masters prefix without X-API-Key when session auth only', async () => {
    await firstValueFrom(service.get('/crops'));
    expect(apiClient.get).toHaveBeenCalledWith(
      '/api/v1/masters/crops',
      expect.objectContaining({
        headers: expect.objectContaining({})
      })
    );
    const options = apiClient.get.mock.calls[0][1] as { headers: { get: (n: string) => string | null } };
    expect(options.headers.get('Accept-Language')).toBe('in');
    expect(options.headers.get('X-API-Key')).toBeNull();
  });

  it('get includes X-API-Key when API key is present', async () => {
    apiKeyService.getApiKey.mockReturnValue('test-api-key');
    await firstValueFrom(service.get('/crops'));
    const options = apiClient.get.mock.calls[0][1] as { headers: { get: (n: string) => string | null } };
    expect(options.headers.get('X-API-Key')).toBe('test-api-key');
  });

  describe('deleteWithUndo', () => {
    it('calls masters DELETE and returns parsed undo payload', async () => {
      apiClient.delete.mockReturnValue(
        of({
          undo_token: 'flat-token',
          undo_path: '/undo_deletion?undo_token=flat-token',
          toast_message: 'deleted'
        })
      );

      const result = await firstValueFrom(service.deleteWithUndo('/farms/42'));
      expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/masters/farms/42', {
        headers: expect.objectContaining({})
      });
      expect(result?.undo_token).toBe('flat-token');
    });
  });
});
