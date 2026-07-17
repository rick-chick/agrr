import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { MasterContextHeaderComponent } from './master-context-header.component';

describe('MasterContextHeaderComponent', () => {
  let fixture: ComponentFixture<MasterContextHeaderComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MasterContextHeaderComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(MasterContextHeaderComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      farms: { index: { title: 'Farms' } },
      common: { edit: 'Edit' }
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders list and current crumbs with expected router links and labels', () => {
    fixture.componentRef.setInput('crumbs', [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] },
      { label: 'North Farm' }
    ]);
    fixture.detectChanges();

    const crumbs = fixture.nativeElement.querySelectorAll('.master-context-header__crumb');
    expect(crumbs).toHaveLength(2);

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.textContent?.trim()).toBe('Farms');
    expect(backLink.getAttribute('href')).toBe('/farms');

    const current = fixture.nativeElement.querySelector('[aria-current="page"]');
    expect(current?.textContent?.trim()).toBe('North Farm');
    expect(fixture.nativeElement.querySelectorAll('a.btn-secondary')).toHaveLength(0);
  });

  it('renders a single list crumb as a back link during loading', () => {
    fixture.componentRef.setInput('crumbs', [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] }
    ]);
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.textContent?.trim()).toBe('Farms');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')).toBeNull();
  });

  it('renders optional forward link in the header bar', () => {
    fixture.componentRef.setInput('crumbs', [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] },
      { label: 'North Farm' }
    ]);
    fixture.componentRef.setInput('forwardRouterLink', ['/farms', 1, 'edit']);
    fixture.componentRef.setInput('forwardLabelKey', 'common.edit');
    fixture.detectChanges();

    const forward = fixture.nativeElement.querySelector(
      'a.master-context-header__forward'
    ) as HTMLAnchorElement;
    expect(forward).toBeTruthy();
    expect(forward.getAttribute('href')).toBe('/farms/1/edit');
    expect(forward.textContent?.trim()).toBe('Edit');
    expect(forward.classList.contains('btn-secondary')).toBe(false);
  });

  it('exposes breadcrumb navigation for assistive technologies', () => {
    fixture.componentRef.setInput('crumbs', [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] },
      { label: 'North Farm' }
    ]);
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('nav.master-context-header__nav');
    expect(nav).toBeTruthy();
    expect(nav.getAttribute('aria-label')).toBeTruthy();
  });
});
