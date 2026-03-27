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
});
