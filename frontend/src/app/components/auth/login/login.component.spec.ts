import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { LoginComponent } from './login.component';
import { AuthService } from '../../../services/auth.service';

function stubWindowLocation(partial: Pick<Location, 'href' | 'pathname' | 'origin'>): void {
  Object.defineProperty(window, 'location', {
    configurable: true,
    writable: true,
    value: {
      href: partial.href,
      pathname: partial.pathname,
      origin: partial.origin,
      hostname: 'localhost',
      port: '4200',
      protocol: 'http:',
      search: '',
      hash: ''
    }
  });
}

describe('LoginComponent', () => {
  let authService: { loadCurrentUser: ReturnType<typeof vi.fn> };
  let router: { navigateByUrl: ReturnType<typeof vi.fn> };

  const loggedInUser = {
    id: 1,
    name: 'Test',
    email: 't@example.com',
    avatar_url: null as string | null,
    admin: false
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    authService = { loadCurrentUser: vi.fn(() => of(null)) };
    router = { navigateByUrl: vi.fn(() => Promise.resolve(true)) };

    stubWindowLocation({
      href: 'http://localhost:4200/login',
      pathname: '/login',
      origin: 'http://localhost:4200'
    });

    await TestBed.configureTestingModule({
      imports: [LoginComponent, TranslateModule.forRoot()],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: Router, useValue: router }
      ]
    }).compileComponents();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('sets return_to to origin root when pathname is /login', () => {
    stubWindowLocation({
      href: 'http://localhost:4200/login',
      pathname: '/login',
      origin: 'http://localhost:4200'
    });
    const fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
    const href = fixture.nativeElement.querySelector('a.login-button')?.getAttribute('href');
    expect(href).toContain(`return_to=${encodeURIComponent('http://localhost:4200/')}`);
  });

  it('sets return_to to origin root when pathname is /login/', () => {
    stubWindowLocation({
      href: 'http://localhost:4200/login/',
      pathname: '/login/',
      origin: 'http://localhost:4200'
    });
    const fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
    const href = fixture.nativeElement.querySelector('a.login-button')?.getAttribute('href');
    expect(href).toContain(`return_to=${encodeURIComponent('http://localhost:4200/')}`);
  });

  it('sets return_to to full href when not on login path', () => {
    stubWindowLocation({
      href: 'http://localhost:4200/plans?tab=1',
      pathname: '/plans',
      origin: 'http://localhost:4200'
    });
    const fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
    const href = fixture.nativeElement.querySelector('a.login-button')?.getAttribute('href');
    expect(href).toContain(`return_to=${encodeURIComponent('http://localhost:4200/plans?tab=1')}`);
  });

  it('navigates home with replaceUrl when user is already logged in', () => {
    authService.loadCurrentUser.mockReturnValue(of(loggedInUser));
    const fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/', { replaceUrl: true });
  });

  it('does not navigate when user is null', () => {
    authService.loadCurrentUser.mockReturnValue(of(null));
    const fixture = TestBed.createComponent(LoginComponent);
    fixture.detectChanges();
    expect(router.navigateByUrl).not.toHaveBeenCalled();
  });
});
