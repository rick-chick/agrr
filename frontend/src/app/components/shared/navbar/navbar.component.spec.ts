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

  it('uses design-system classes on nav chrome buttons', () => {
    component.user = {
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      avatar_url: null,
      admin: false,
    };
    fixture.detectChanges();

    const menuToggle = fixture.nativeElement.querySelector('button.menu-toggle') as HTMLButtonElement;
    expect(menuToggle).toBeTruthy();
    expect(menuToggle.classList.contains('btn')).toBe(true);
    expect(menuToggle.classList.contains('btn-secondary')).toBe(true);
    expect(menuToggle.classList.contains('btn-sm')).toBe(true);

    const logoutButton = fixture.nativeElement.querySelector('button.logout-button') as HTMLButtonElement;
    expect(logoutButton).toBeTruthy();
    expect(logoutButton.classList.contains('btn')).toBe(true);
    expect(logoutButton.classList.contains('btn-secondary')).toBe(true);
    expect(logoutButton.classList.contains('btn-sm')).toBe(true);
  });
});
