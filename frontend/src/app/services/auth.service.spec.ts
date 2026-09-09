import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { of, firstValueFrom, throwError } from 'rxjs';

import { ApiService } from './api.service';
import { ApiKeyService } from './api-key.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let apiService: {
    getCurrentUser: ReturnType<typeof vi.fn>;
    logout: ReturnType<typeof vi.fn>;
  };
  let apiKeyService: {
    setApiKey: ReturnType<typeof vi.fn>;
    clearApiKey: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    apiService = {
      getCurrentUser: vi.fn(),
      logout: vi.fn()
    };
    apiKeyService = {
      setApiKey: vi.fn(),
      clearApiKey: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: ApiService, useValue: apiService },
        { provide: ApiKeyService, useValue: apiKeyService }
      ]
    });

    service = TestBed.inject(AuthService);
  });

  it('should clear stale API key when loading current user without persisting /me key', async () => {
    const mockUser = {
      id: 1,
      name: 'Test User',
      api_key: 'agr_****7890'
    };

    apiService.getCurrentUser.mockReturnValue(of({ user: mockUser }));

    await firstValueFrom(service.loadCurrentUser());

    expect(apiKeyService.clearApiKey).toHaveBeenCalled();
    expect(apiKeyService.setApiKey).not.toHaveBeenCalled();
    expect(service.user()).toEqual(mockUser);
    expect(service.sessionUnavailable()).toBe(false);
  });

  it('should clear API key on logout', async () => {
    apiService.logout.mockReturnValue(of({ success: true }));

    await firstValueFrom(service.logout());

    expect(apiKeyService.clearApiKey).toHaveBeenCalled();
    expect(service.user()).toBeNull();
    expect(service.sessionUnavailable()).toBe(false);
  });

  it('treats 401 as unauthenticated without session unavailable', async () => {
    apiService.getCurrentUser.mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' }))
    );

    await firstValueFrom(service.loadCurrentUser());

    expect(service.user()).toBeNull();
    expect(service.sessionUnavailable()).toBe(false);
  });

  it('treats 5xx as session unavailable without clearing to logged-out state', async () => {
    apiService.getCurrentUser.mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 500, statusText: 'Internal Server Error' }))
    );

    await firstValueFrom(service.loadCurrentUser());

    expect(service.user()).toBeNull();
    expect(service.sessionUnavailable()).toBe(true);
  });

  it('treats 503 as database warming instead of session unavailable', async () => {
    apiService.getCurrentUser.mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    await firstValueFrom(service.loadCurrentUser());

    expect(service.databaseWarming()).toBe(true);
    expect(service.sessionUnavailable()).toBe(false);
    expect(service.user()).toBeNull();
  });

  it('retryLoadCurrentUser clears session unavailable and reloads', async () => {
    apiService.getCurrentUser
      .mockReturnValueOnce(
        throwError(() => new HttpErrorResponse({ status: 500, statusText: 'Internal Server Error' }))
      )
      .mockReturnValueOnce(of({ user: { id: 1, name: 'Recovered' } }));

    await firstValueFrom(service.loadCurrentUser());
    expect(service.sessionUnavailable()).toBe(true);

    await firstValueFrom(service.retryLoadCurrentUser());

    expect(service.sessionUnavailable()).toBe(false);
    expect(service.user()).toEqual(expect.objectContaining({ id: 1, name: 'Recovered' }));
    expect(apiService.getCurrentUser).toHaveBeenCalledTimes(2);
  });
});
