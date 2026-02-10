import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { NavbarComponent } from './navbar.component';

describe('NavbarComponent', () => {
  let component: NavbarComponent;
  let fixture: ComponentFixture<NavbarComponent>;
  let translateService: TranslateService;

  beforeEach(async () => {
    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [NavbarComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(NavbarComponent);
    component = fixture.componentInstance;
    translateService = TestBed.inject(TranslateService);
    translateService.setDefaultLang('en');
    component.apiBaseUrl = 'https://api.example.com';
  });

  it('returns /research/en/ when language is en', () => {
    translateService.use('en');
    fixture.detectChanges();
    expect(component.reportUrl).toBe('https://api.example.com/research/en/');
  });

  it('returns /research/ when language is ja', () => {
    translateService.use('ja');
    fixture.detectChanges();
    expect(component.reportUrl).toBe('https://api.example.com/research/');
  });

  it('returns /research/ when language is in', () => {
    translateService.use('in');
    fixture.detectChanges();
    expect(component.reportUrl).toBe('https://api.example.com/research/');
  });

  it('normalizes base URL by stripping trailing slash before appending path', () => {
    component.apiBaseUrl = 'https://api.example.com/';
    translateService.use('en');
    fixture.detectChanges();
    expect(component.reportUrl).toBe('https://api.example.com/research/en/');
  });
});
