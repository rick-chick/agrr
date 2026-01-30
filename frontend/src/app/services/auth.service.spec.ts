import { describe, it, expect, vi, beforeEach } from 'vitest';
import { of, firstValueFrom, tap, map, catchError } from 'rxjs';

// Logic from auth.service.ts
class AuthServiceLogic {
  private userSignal: any = null;
  private loaded = false;

  constructor(private api: any, private apiKeyService: any) {}

  user() { return this.userSignal; }

  loadCurrentUser() {
    if (this.loaded) return of(this.userSignal);
    return this.api.getCurrentUser().pipe(
      map((response: any) => response.user),
      tap((user: any) => {
        if (user.api_key) {
          this.apiKeyService.setApiKey(user.api_key);
        }
        this.userSignal = user;
        this.loaded = true;
      }),
      catchError(() => {
        this.userSignal = null;
        this.loaded = true;
        return of(null);
      })
    );
  }

  ensureApiKey(obs$: any) {
    return this.loadCurrentUser().pipe(
      () => obs$
    );
  }

  logout() {
    return this.api.logout().pipe(
      tap(() => {
        this.apiKeyService.clearApiKey();
        this.userSignal = null;
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

  it('should set API key when loading current user', async () => {
    const mockUser = {
      id: 1,
      name: 'Test User',
      api_key: 'new-api-key'
    };

    apiService.getCurrentUser.mockReturnValue(of({ user: mockUser }));

    await firstValueFrom(service.loadCurrentUser());
    
    expect(apiKeyService.setApiKey).toHaveBeenCalledWith('new-api-key');
    expect(service.user()).toEqual(mockUser);
  });

  it('should clear API key on logout', async () => {
    apiService.logout.mockReturnValue(of({ success: true }));

    await firstValueFrom(service.logout());
    
    expect(apiKeyService.clearApiKey).toHaveBeenCalled();
    expect(service.user()).toBeNull();
  });
});
