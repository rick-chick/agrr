import { TestBed } from '@angular/core/testing';
import { Router, UrlTree } from '@angular/router';
import { firstValueFrom, isObservable, of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { authGuard } from './auth.guard';
import { AuthService } from '../services/auth.service';

const origin = 'http://localhost:4200';

describe('authGuard', () => {
  let authService: { user: ReturnType<typeof vi.fn>; loadCurrentUser: ReturnType<typeof vi.fn> };
  let createUrlTree: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    authService = {
      user: vi.fn(() => null),
      loadCurrentUser: vi.fn(() => of(null))
    };
    createUrlTree = vi.fn((_commands: string[], extras?: { queryParams?: Record<string, string> }) => {
      const tree = new UrlTree();
      (tree as { queryParams?: Record<string, string> }).queryParams = extras?.queryParams;
      return tree;
    });

    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: authService },
        {
          provide: Router,
          useValue: { createUrlTree }
        }
      ]
    });

    vi.stubGlobal('window', {
      location: { origin }
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  async function runGuard(targetUrl: string) {
    const result = TestBed.runInInjectionContext(() =>
      authGuard({} as never, { url: targetUrl } as never)
    );
    if (isObservable(result)) {
      return firstValueFrom(result);
    }
    return result;
  }

  it('allows access when user is already loaded', async () => {
    authService.user.mockReturnValue({ id: 1 });
    expect(await runGuard('/plans/123')).toBe(true);
  });

  it('allows access when loadCurrentUser returns a user', async () => {
    authService.loadCurrentUser.mockReturnValue(of({ id: 1 }));
    expect(await runGuard('/plans/123')).toBe(true);
  });

  it('redirects to /login with return_to when unauthenticated', async () => {
    const result = await runGuard('/plans/123');
    expect(createUrlTree).toHaveBeenCalledWith(['/login'], {
      queryParams: {
        return_to: `${origin}/?_post_login=${encodeURIComponent('/plans/123')}`
      }
    });
    expect(result).toBeInstanceOf(UrlTree);
  });
});
