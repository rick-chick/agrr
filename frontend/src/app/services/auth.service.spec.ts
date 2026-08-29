import { HttpErrorResponse } from '@angular/common/http';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { of, firstValueFrom, tap, map, catchError, throwError } from 'rxjs';
import { detectBrowserRegion } from '../core/browser-region';
import {
  isAuthMeSessionUnavailableError,
  isAuthMeUnauthenticatedError
} from '../core/auth/auth-me-error';

// Logic from auth.service.ts
class AuthServiceLogic {
  private userSignal: any = null;
  private sessionUnavailableSignal = false;
  private loaded = false;

  constructor(private api: any, private apiKeyService: any) {}

  user() {
    return this.userSignal;
  }

  sessionUnavailable() {
    return this.sessionUnavailableSignal;
  }

  loadCurrentUser() {
    if (this.loaded) return of(this.userSignal);
    return this.api.getCurrentUser().pipe(
      map((response: any) => response.user),
      tap((user: any) => {
        this.apiKeyService.clearApiKey();
        user.region = user.region ?? detectBrowserRegion();
        this.userSignal = user;
        this.sessionUnavailableSignal = false;
        this.loaded = true;
      }),
      catchError((error: unknown) => {
        if (isAuthMeSessionUnavailableError(error)) {
          this.sessionUnavailableSignal = true;
        } else if (isAuthMeUnauthenticatedError(error)) {
          this.userSignal = null;
          this.sessionUnavailableSignal = false;
        } else {
          this.userSignal = null;
          this.sessionUnavailableSignal = false;
        }
        this.loaded = true;
        return of(null);
      })
    );
  }

  retryLoadCurrentUser() {
    this.loaded = false;
    this.sessionUnavailableSignal = false;
    return this.loadCurrentUser();
  }

  logout() {
    return this.api.logout().pipe(
      tap(() => {
        this.apiKeyService.clearApiKey();
        this.userSignal = null;
        this.sessionUnavailableSignal = false;
      })
    );
  }
}

describe('AuthService Logic Verification', () => {
  let service: AuthServiceLogic;
  let apiService: any;
  let apiKeyService: any;

  beforeEach(() => {
    apiService = {
      getCurrentUser: vi.fn(),
      logout: vi.fn()
    };
    apiKeyService = {
      setApiKey: vi.fn(),
      clearApiKey: vi.fn()
    };
    service = new AuthServiceLogic(apiService, apiKeyService);
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

  it('treats 503 as session unavailable', async () => {
    apiService.getCurrentUser.mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    await firstValueFrom(service.loadCurrentUser());

    expect(service.sessionUnavailable()).toBe(true);
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
