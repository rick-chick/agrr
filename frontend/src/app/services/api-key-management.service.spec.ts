import { TestBed } from '@angular/core/testing';
import { firstValueFrom, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService } from './api.service';
import { ApiKeyService } from './api-key.service';
import { AuthService } from './auth.service';
import { ApiKeyManagementService } from './api-key-management.service';

describe('ApiKeyManagementService', () => {
  let service: ApiKeyManagementService;
  let apiService: { post: ReturnType<typeof vi.fn> };
  let authService: {
    loadCurrentUser: ReturnType<typeof vi.fn>;
    user: ReturnType<typeof vi.fn>;
  };
  let apiKeyService: {
    getApiKey: ReturnType<typeof vi.fn>;
    setApiKey: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    apiService = { post: vi.fn() };
    authService = {
      loadCurrentUser: vi.fn(() => of(null)),
      user: vi.fn(() => null)
    };
    apiKeyService = {
      getApiKey: vi.fn(() => null),
      setApiKey: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        ApiKeyManagementService,
        { provide: ApiService, useValue: apiService },
        { provide: AuthService, useValue: authService },
        { provide: ApiKeyService, useValue: apiKeyService }
      ]
    });

    service = TestBed.inject(ApiKeyManagementService);
  });

  it('returns api_key from current user after load', async () => {
    authService.user.mockReturnValue({ id: 1, api_key: 'user-key' });

    await expect(firstValueFrom(service.getCurrentKey())).resolves.toBe('user-key');
    expect(authService.loadCurrentUser).toHaveBeenCalled();
  });

  it('falls back to ApiKeyService when user has no api_key', async () => {
    authService.user.mockReturnValue({ id: 1, api_key: null });
    apiKeyService.getApiKey.mockReturnValue('stored-key');

    await expect(firstValueFrom(service.getCurrentKey())).resolves.toBe('stored-key');
  });

  it('generates a key via POST /api/v1/api_keys/generate and stores it', async () => {
    apiService.post.mockReturnValue(of({ api_key: 'new-key' }));

    await expect(firstValueFrom(service.generateKey())).resolves.toBe('new-key');

    expect(apiService.post).toHaveBeenCalledWith('/api/v1/api_keys/generate', {});
    expect(apiKeyService.setApiKey).toHaveBeenCalledWith('new-key');
  });

  it('regenerates a key via POST /api/v1/api_keys/regenerate and stores it', async () => {
    apiService.post.mockReturnValue(of({ api_key: 'rotated-key' }));

    await expect(firstValueFrom(service.regenerateKey())).resolves.toBe('rotated-key');

    expect(apiService.post).toHaveBeenCalledWith('/api/v1/api_keys/regenerate', {});
    expect(apiKeyService.setApiKey).toHaveBeenCalledWith('rotated-key');
  });

  it('propagates generate errors without storing a key', async () => {
    apiService.post.mockReturnValue(throwError(() => new Error('network')));

    await expect(firstValueFrom(service.generateKey())).rejects.toThrow('network');
    expect(apiKeyService.setApiKey).not.toHaveBeenCalled();
  });
});
