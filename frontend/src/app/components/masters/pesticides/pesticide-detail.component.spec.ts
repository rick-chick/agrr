import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { vi } from 'vitest';
import { PesticideDetailComponent } from './pesticide-detail.component';
import { LoadPesticideDetailUseCase } from '../../../usecase/pesticides/load-pesticide-detail.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import { PesticideDetailPresenter } from '../../../usecase/pesticides/pesticide-detail.providers';

describe('PesticideDetailComponent', () => {
  let component: PesticideDetailComponent;
  let fixture: ComponentFixture<PesticideDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PesticideDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        PesticideDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: LoadPesticideDetailUseCase, useValue: { execute: vi.fn() } },
        { provide: DeletePesticideUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(PesticideDetailComponent, {
        set: {
          providers: [
            { provide: LoadPesticideDetailUseCase, useValue: { execute: vi.fn() } },
            { provide: DeletePesticideUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(PesticideDetailComponent);
    component = fixture.componentInstance;
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      pesticides: {
        fallback: {
          crop: 'Crop (ID:{{id}})',
          pest: 'Pest (ID:{{id}})'
        }
      }
    });
    translate.use('en');
  });

  it('displays API crop_name and pest_name when present', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false,
        crop_name: 'Tomato',
        pest_name: 'Aphid'
      },
      pendingUndoToast: null,
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Tomato');
    expect(el.textContent).toContain('Aphid');
    expect(el.textContent).not.toContain('Crop (ID:51)');
    expect(el.textContent).not.toContain('Pest (ID:54)');
  });

  it('falls back to translated ID label when names are missing', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false
      },
      pendingUndoToast: null,
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Crop (ID:51)');
    expect(el.textContent).toContain('Pest (ID:54)');
  });

  it('shows master context header and omits back button from detail-card__actions', () => {
    translate.setTranslation('en', {
      pesticides: {
        index: { title: 'Pesticides' },
        show: {
          name: 'Name',
          crop: 'Crop',
          pest: 'Pest',
          edit: 'Edit',
          delete: 'Delete'
        },
        fallback: {
          crop: 'Crop (ID:{{id}})',
          pest: 'Pest (ID:{{id}})'
        }
      }
    });
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false,
        crop_name: 'Tomato',
        pest_name: 'Aphid'
      },
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/pesticides');
    expect(backLink?.textContent?.trim()).toContain('Pesticides');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Spray A'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });

  it('shows i18n load error panel with back link and retry on API failure', () => {
    translate.setTranslation('en', {
      pesticides: { index: { title: 'Pesticides' } },
      'common.api_error.generic': 'An error occurred',
      'masters.load_error.retry': 'Reload'
    });
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      pendingErrorFlash: null,
      pesticide: null,
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.master-load-error');
    expect(alert?.textContent).toContain('An error occurred');
    expect(alert?.textContent).not.toContain('Http failure');
    expect(
      (fixture.nativeElement.querySelector('a.master-load-error__back') as HTMLAnchorElement)?.getAttribute(
        'href'
      )
    ).toBe('/pesticides');
  });

  it('reloads detail when retry is clicked after load error', () => {
    const loadUseCase = TestBed.inject(LoadPesticideDetailUseCase) as { execute: ReturnType<typeof vi.fn> };
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      pendingErrorFlash: null,
      pesticide: null,
      pendingUndoToast: null
    };
    fixture.detectChanges();

    loadUseCase.execute.mockClear();
    fixture.nativeElement.querySelector('.master-load-error__retry')?.click();

    expect(loadUseCase.execute).toHaveBeenCalledWith({ pesticideId: 1 });
  });
});
