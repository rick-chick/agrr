import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { NavbarComponent } from './navbar.component';

describe('NavbarComponent', () => {
  let component: NavbarComponent;
  let fixture: ComponentFixture<NavbarComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [NavbarComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(NavbarComponent);
    component = fixture.componentInstance;
    translate = TestBed.inject(TranslateService);
    component.apiBaseUrl = 'https://api.example.com';
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
});
