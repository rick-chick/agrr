import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Meta } from '@angular/platform-browser';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { LoginComponent } from './login.component';
import { AuthService } from '../../../services/auth.service';

const origin = 'http://localhost:4200';

describe('LoginComponent', () => {
  let authService: { loadCurrentUser: ReturnType<typeof vi.fn> };
  let router: { navigateByUrl: ReturnType<typeof vi.fn> };
  let queryParamMap: { get: ReturnType<typeof vi.fn> };
  let fixture: ComponentFixture<LoginComponent>;
  let meta: Meta;

  beforeEach(async () => {
    authService = {
      loadCurrentUser: vi.fn(() => of({ id: 1 }))
    };
    router = {
      navigateByUrl: vi.fn(() => Promise.resolve(true))
    };
    queryParamMap = { get: vi.fn(() => null) };

    vi.stubGlobal('window', {
      location: { href: `${origin}/login`, pathname: '/login', origin }
    });

    await TestBed.configureTestingModule({
      imports: [LoginComponent, TranslateModule.forRoot()],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: Router, useValue: router },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { queryParamMap }
          }
        }
      ]
    }).compileComponents();

    meta = TestBed.inject(Meta);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  function createAndInit(): void {
    fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
  }

  it('redirects logged-in user to / when return_to is absent', () => {
    createAndInit();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/', { replaceUrl: true });
  });

  it('redirects logged-in user using return_to query', () => {
    const resultsUrl = `${origin}/public-plans/results?planId=1`;
    queryParamMap.get.mockReturnValue(resultsUrl);

    createAndInit();

    expect(router.navigateByUrl).toHaveBeenCalledWith('/public-plans/results?planId=1', {
      replaceUrl: true
    });
  });

  it('sets robots noindex meta while displayed for unauthenticated users', () => {
    authService.loadCurrentUser.mockReturnValue(of(null));
    createAndInit();
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');
  });

  it('removes robots noindex on destroy', () => {
    authService.loadCurrentUser.mockReturnValue(of(null));
    createAndInit();
    fixture.destroy();
    expect(meta.getTag('name="robots"')).toBeNull();
  });

  it('shows i18n error banner when error query param is present', () => {
    authService.loadCurrentUser.mockReturnValue(of(null));
    queryParamMap.get.mockImplementation((key: string) =>
      key === 'error' ? 'oauth_denied' : null
    );

    createAndInit();

    const banner = fixture.nativeElement.querySelector('[role="alert"]');
    expect(banner).toBeTruthy();
    expect(banner.textContent).toContain('auth.login.errors.oauth_denied');
  });

  it('does not show error banner when error query param is absent', () => {
    authService.loadCurrentUser.mockReturnValue(of(null));
    queryParamMap.get.mockReturnValue(null);

    createAndInit();

    expect(fixture.nativeElement.querySelector('[role="alert"]')).toBeNull();
  });
});
