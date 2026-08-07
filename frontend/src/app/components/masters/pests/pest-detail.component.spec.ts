import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PestDetailComponent } from './pest-detail.component';
import { LoadPestDetailUseCase } from '../../../usecase/pests/load-pest-detail.usecase';
import { DeletePestUseCase } from '../../../usecase/pests/delete-pest.usecase';
import { PestDetailPresenter } from '../../../usecase/pests/pest-detail.providers';

describe('PestDetailComponent', () => {
  let fixture: ComponentFixture<PestDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PestDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        PestDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: LoadPestDetailUseCase, useValue: { execute: vi.fn() } },
        { provide: DeletePestUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(PestDetailComponent, {
        set: {
          providers: [
            { provide: LoadPestDetailUseCase, useValue: { execute: vi.fn() } },
            { provide: DeletePestUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(PestDetailComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      pests: {
        index: { title: 'Pests' },
        show: {
          name: 'Name',
          edit: 'Edit',
          delete: 'Delete'
        }
      }
    });
    translate.use('en');
  });

  it('shows master context header and omits back button from detail-card__actions', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pest: {
        id: 1,
        name: 'Aphid',
        is_reference: false
      },
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/pests');
    expect(backLink?.textContent?.trim()).toContain('Pests');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Aphid'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });

  it('renders translated region value instead of raw region code', () => {
    translate.setTranslation('en', {
      pests: {
        index: { title: 'Pests' },
        show: {
          name: 'Name',
          region: 'Region',
          edit: 'Edit',
          delete: 'Delete'
        },
        form: {
          region_jp: 'Japan',
          region_us: 'United States',
          region_in: 'India'
        }
      }
    });
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pest: {
        id: 1,
        name: 'Aphid',
        region: 'us',
        is_reference: false
      },
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Region');
    expect(el.textContent).toContain('United States');
    expect(el.textContent).not.toContain('region_us');
    expect(el.textContent).not.toMatch(/\bus\b/);
  });

  it('keeps list breadcrumb link while loading', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: true,
      error: null,
      pendingErrorFlash: null,
      pest: null,
      pendingUndoToast: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('a.master-context-header__back')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')).toBeNull();
  });

  it('shows i18n load error panel with back link and retry on API failure', () => {
    translate.setTranslation('en', {
      pests: { index: { title: 'Pests' } },
      'common.api_error.not_found': 'Resource not found',
      'masters.load_error.retry': 'Reload'
    });
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: 'common.api_error.not_found',
      pendingErrorFlash: null,
      pest: null,
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.master-load-error');
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(alert?.textContent).toContain('Resource not found');
    expect(
      (fixture.nativeElement.querySelector('a.master-load-error__back') as HTMLAnchorElement)?.getAttribute(
        'href'
      )
    ).toBe('/pests');
  });
});
