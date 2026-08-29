import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { NavbarComponent } from './navbar.component';

@Component({ template: '' })
class DummyRouteComponent {}

describe('NavbarComponent', () => {
  let component: NavbarComponent;
  let fixture: ComponentFixture<NavbarComponent>;
  let translate: TranslateService;
  let router: Router;

  beforeEach(async () => {
    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [NavbarComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([
          { path: 'work', component: DummyRouteComponent },
          { path: 'plans/:id/work', component: DummyRouteComponent },
          { path: 'plans/:id/task_schedule', component: DummyRouteComponent },
          { path: 'plans/:id', component: DummyRouteComponent }
        ])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(NavbarComponent);
    component = fixture.componentInstance;
    translate = TestBed.inject(TranslateService);
    router = TestBed.inject(Router);
  });

  it('uses /research/ for ja locale', () => {
    translate.setDefaultLang('ja');
    translate.use('ja');
    fixture.detectChanges();
    expect(component.reportUrl).toBe(`${window.location.origin}/research/`);
  });

  it('uses /research/en/ for en locale', () => {
    translate.setDefaultLang('ja');
    translate.use('en');
    fixture.detectChanges();
    expect(component.reportUrl).toBe(`${window.location.origin}/research/en/`);
  });

  it('uses /research/en/ for in locale (English research fallback)', () => {
    translate.setDefaultLang('ja');
    translate.use('in');
    fixture.detectChanges();
    expect(component.reportUrl).toBe(`${window.location.origin}/research/en/`);
  });

  it('maps developer mock user to locale-aware short label', () => {
    translate.setTranslation('en', {
      auth: { login: { dev_login_as_developer: 'Login as Developer' } },
    });
    translate.setDefaultLang('ja');
    translate.use('en');
    fixture.detectChanges();
    expect(
      component.displayUserName({
        id: 1,
        name: '開発者',
        email: 'developer@agrr.dev',
        avatar_url: null,
        admin: true,
      }),
    ).toBe('Developer');
  });

  it('maps developer mock user to Hindi short label', () => {
    translate.setTranslation('in', {
      auth: { login: { dev_login_as_developer: 'डेवलपर के रूप में लॉगिन' } },
    });
    translate.use('in');
    fixture.detectChanges();
    expect(
      component.displayUserName({
        id: 1,
        name: '開発者',
        email: 'developer@agrr.dev',
        avatar_url: null,
        admin: true,
      }),
    ).toBe('डेवलपर');
  });

  it('marks work log active on /work', async () => {
    await router.navigateByUrl('/work');
    fixture.detectChanges();
    expect(component.isWorkLogNavActive()).toBe(true);
    expect(component.isPlanNavActive()).toBe(false);
  });

  it('marks work log active on plan work routes', async () => {
    await router.navigateByUrl('/plans/12/work');
    fixture.detectChanges();
    expect(component.isWorkLogNavActive()).toBe(true);
    expect(component.isPlanNavActive()).toBe(false);
  });

  it('marks plan active on plan detail but not on work routes', async () => {
    await router.navigateByUrl('/plans/12');
    fixture.detectChanges();
    expect(component.isPlanNavActive()).toBe(true);
    expect(component.isWorkLogNavActive()).toBe(false);

    await router.navigateByUrl('/plans/12/task_schedule');
    fixture.detectChanges();
    expect(component.isPlanNavActive()).toBe(true);
    expect(component.isWorkLogNavActive()).toBe(false);
  });

  it('menu toggle CSS uses minimum touch target token', () => {
    const cssPath = join(dirname(fileURLToPath(import.meta.url)), 'navbar.component.css');
    const css = readFileSync(cssPath, 'utf8');
    const menuToggleBlock = css.match(/\.menu-toggle\s*\{[^}]+\}/s)?.[0] ?? '';
    expect(menuToggleBlock).toContain('width: var(--touch-target-min)');
    expect(menuToggleBlock).toContain('height: var(--touch-target-min)');
    expect(menuToggleBlock).not.toContain('width: 32px');
    expect(menuToggleBlock).not.toContain('height: 32px');
  });

  it('menu toggle preserves a11y attributes', () => {
    fixture.detectChanges();
    const menuToggle = fixture.nativeElement.querySelector('.menu-toggle') as HTMLButtonElement;
    expect(menuToggle).toBeTruthy();
    expect(menuToggle.getAttribute('aria-expanded')).toBe('false');
    expect(menuToggle.getAttribute('aria-label')).toBeTruthy();
  });

  it('toggles mobile menu via hamburger button', () => {
    fixture.detectChanges();
    const menuToggle = fixture.nativeElement.querySelector('.menu-toggle') as HTMLButtonElement;
    menuToggle.click();
    fixture.detectChanges();
    expect(component.isMenuOpen).toBe(true);
    expect(menuToggle.getAttribute('aria-expanded')).toBe('true');
  });

  it('closes mobile menu after route navigation', async () => {
    fixture.detectChanges();
    component.isMenuOpen = true;
    component.openDropdownId = 'masters';
    expect(component.isMenuOpen).toBe(true);

    await router.navigateByUrl('/work');
    fixture.detectChanges();

    expect(component.isMenuOpen).toBe(false);
    expect(component.openDropdownId).toBeNull();
  });

  it('includes account and api-keys in moreItems when user is logged in', () => {
    component.user = {
      id: 1,
      name: 'Test',
      email: 'test@example.com',
      avatar_url: null,
      admin: false
    };
    fixture.detectChanges();

    expect(component.moreItems[0]).toEqual({ link: '/account', labelKey: 'nav.account' });
    expect(component.moreItems[1]).toEqual({ link: '/api-keys', labelKey: 'nav.api_keys' });
  });

  it('omits account and api-keys from moreItems when user is logged out', () => {
    component.user = null;
    fixture.detectChanges();

    expect(component.moreItems.some((item) => item.link === '/account')).toBe(false);
    expect(component.moreItems.some((item) => item.link === '/api-keys')).toBe(false);
  });

  it('shows session unavailable status and retry instead of login link', () => {
    translate.setTranslation('en', {
      status: {
        session_unavailable: 'Could not verify your session',
        retry: 'Retry'
      },
      nav: { login: 'Login' }
    });
    translate.use('en');
    component.user = null;
    component.sessionUnavailable = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Could not verify your session');
    expect(fixture.nativeElement.querySelector('.retry-button')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.login-link')).toBeNull();
  });

  it('shows overdue badge when workLogOverdueCount is positive', () => {
    translate.setTranslation('ja', {
      nav: { work_log: '作業記録', work_log_overdue_aria: '作業記録、期限超過 {{count}} 件' }
    });
    translate.use('ja');
    component.user = {
      id: 1,
      name: 'Test',
      email: 'test@example.com',
      avatar_url: null,
      admin: false
    };
    component.workLogOverdueCount = 3;
    fixture.detectChanges();

    const workLogLink = fixture.nativeElement.querySelector(
      'a.nav-link--with-badge'
    ) as HTMLAnchorElement;
    expect(workLogLink.getAttribute('href')).toContain('/work');
    expect(workLogLink.getAttribute('aria-label')).toBe('作業記録、期限超過 3 件');
    expect(workLogLink.querySelector('.nav-link__badge')?.textContent?.trim()).toBe('3');
  });

  it('shows entry schedule nav link for logged-out users', () => {
    translate.setTranslation('en', { nav: { entry_schedule: 'Entry schedule' } });
    translate.use('en');
    component.user = null;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      'a.nav-link[href="/entry-schedule"]'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.textContent?.trim()).toBe('Entry schedule');
  });

  it('hides overdue badge when workLogOverdueCount is zero', () => {
    component.user = {
      id: 1,
      name: 'Test',
      email: 'test@example.com',
      avatar_url: null,
      admin: false
    };
    component.workLogOverdueCount = 0;
    fixture.detectChanges();

    const workLogLink = fixture.nativeElement.querySelector(
      'a.nav-link--with-badge'
    ) as HTMLAnchorElement;
    expect(workLogLink.getAttribute('aria-label')).toBeNull();
    expect(workLogLink.querySelector('.nav-link__badge')).toBeNull();
  });
});
