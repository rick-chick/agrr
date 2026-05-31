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

  beforeEach(() => {
    apiClient = { get: vi.fn().mockReturnValue(of({})), delete: vi.fn() };
    apiKeyService = { getApiKey: vi.fn().mockReturnValue(null) };
    service = new MastersClientService(
      apiClient as unknown as ApiService,
      apiKeyService as unknown as ApiKeyService
    );
    (service as unknown as { translate: TranslateService }).translate = {
      currentLang: 'in',
      defaultLang: 'ja'
    } as TranslateService;
  });

  it('get uses /api/v1/masters prefix without X-API-Key when session auth only', async () => {
    await firstValueFrom(service.get('/crops'));
    expect(apiClient.get).toHaveBeenCalledWith('/api/v1/masters/crops', {});
  });

  it('get includes X-API-Key when API key is present', async () => {
    apiKeyService.getApiKey.mockReturnValue('test-api-key');
    await firstValueFrom(service.get('/crops'));
    expect(apiClient.get).toHaveBeenCalledWith(
      '/api/v1/masters/crops',
      expect.objectContaining({
        headers: expect.objectContaining({})
      })
    );
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
