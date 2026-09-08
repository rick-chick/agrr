import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmListComponent } from './farm-list.component';
import { LoadFarmListUseCase } from '../../../usecase/farms/load-farm-list.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { FarmListPresenter } from '../../../usecase/farms/farm-list.providers';
import { LOAD_FARM_LIST_OUTPUT_PORT } from '../../../usecase/farms/load-farm-list.output-port';
import { DELETE_FARM_OUTPUT_PORT } from '../../../usecase/farms/delete-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmListViewState } from './farm-list.view';

describe('FarmListComponent', () => {
  let component: FarmListComponent;
  let fixture: ComponentFixture<FarmListComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    loadUseCase = { execute: vi.fn() };
    deleteUseCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmListComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(FarmListComponent, {
        set: {
          styleUrls: [],
          styles: [
            `
              .btn-danger {
                background: #ffffff;
                color: #dc2626;
                border: 1px solid #e2e8f0;
              }
            `
          ],
          providers: [
            { provide: LoadFarmListUseCase, useValue: loadUseCase },
            { provide: DeleteFarmUseCase, useValue: deleteUseCase },
            { provide: FarmListPresenter, useValue: presenter },
            { provide: LOAD_FARM_LIST_OUTPUT_PORT, useExisting: FarmListPresenter },
            { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmListPresenter },
            { provide: FARM_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(FarmListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    const translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('en', {
      farms: {
        index: {
          reference_badge: 'Reference',
          delete_confirm_message:
            'Delete this farm? Registered fields and cultivation plans will be affected. You can undo shortly after deleting.'
        },
        form: {
          region_jp: 'Japan'
        }
      },
      common: { cancel: 'Cancel', delete: 'Delete' }
    });
    translateService.use('en');

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmListViewState = {
      loading: false,
      error: null,
      farms: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmListViewState = {
      loading: false,
      error: null,
      farms: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    component.control = state;
    expect(cdr.markForCheck).toHaveBeenCalled();
  });

  it('calls useCase.execute on load', () => {
    component.load();
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('opens delete confirm dialog before calling deleteUseCase', () => {
    const farmId = 123;
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: farmId,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    component.deleteConfirmDialogRef = {
      nativeElement: { showModal: vi.fn(), close: vi.fn() }
    } as never;

    component.deleteFarm(farmId);

    expect(component.deleteConfirmDialogRef?.nativeElement.showModal).toHaveBeenCalled();
    expect(deleteUseCase.execute).not.toHaveBeenCalled();

    component.confirmDeleteFarm();
    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      farmId,
      onAfterUndo: expect.any(Function)
    });
  });

  it('delete confirm dialog shows impact scope message', () => {
    component.pendingDeleteFarmId = 123;
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Registered fields and cultivation plans');
  });

  it('ngOnInit sets view on presenter and calls load', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('delete button uses outline destructive style (surface background, error text)', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };

    fixture.detectChanges();

    const deleteButton = fixture.nativeElement.querySelector(
      '.item-card__actions .btn-danger'
    ) as HTMLButtonElement;
    expect(deleteButton).toBeTruthy();

    const style = getComputedStyle(deleteButton);
    expect(style.backgroundColor).toBe('rgb(255, 255, 255)');
    expect(style.color).toBe('rgb(220, 38, 38)');
  });

  it('renders translated region label instead of raw region code', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };

    fixture.detectChanges();

    const regionRow = fixture.nativeElement.querySelector('.farm-list__region') as HTMLElement;
    expect(regionRow?.textContent?.trim()).toBe('Japan');
    expect(fixture.nativeElement.textContent).not.toContain('region_jp');
    expect(fixture.nativeElement.textContent).not.toMatch(/\bjp\b/);
  });

  it('uses uniform card layout classes for single-line rows', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const body = fixture.nativeElement.querySelector('.farm-list__card-body') as HTMLElement;
    const title = fixture.nativeElement.querySelector('.item-card__title--single-line') as HTMLElement;
    expect(body?.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.farm-list__reference-badge.item-card__meta--single-line')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.farm-list__region.item-card__meta--single-line')).toBeTruthy();
  });

  it('keeps region row in DOM when region is absent for consistent card height', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'No Region Farm',
          region: null,
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const regionRow = fixture.nativeElement.querySelector('.farm-list__region') as HTMLElement;
    expect(regionRow).toBeTruthy();
    expect(regionRow.textContent?.trim()).toBe('');
  });

  it('keeps reference badge row in DOM when farm is not reference', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const badgeRow = fixture.nativeElement.querySelector('.farm-list__reference-badge') as HTMLElement;
    expect(badgeRow).toBeTruthy();
    expect(badgeRow.textContent?.trim()).toBe('');
  });

  it('displays reference badge in separate meta row, not inline in title', () => {
    const farms = [
      { id: 1, name: 'User Farm', region: 'jp', latitude: 35.6895, longitude: 139.6917, weather_data_status: 'completed' as const, is_reference: false },
      { id: 2, name: 'Reference Farm', region: 'jp', latitude: 43.0642, longitude: 141.3468, weather_data_status: 'pending' as const, is_reference: true }
    ];

    component.control = {
      loading: false,
      error: null,
      farms,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };

    fixture.detectChanges();

    const farmTitles = fixture.nativeElement.querySelectorAll('.item-card__title');
    expect(farmTitles).toHaveLength(2);
    expect(farmTitles[0].textContent?.trim()).toBe('User Farm');
    expect(farmTitles[1].textContent?.trim()).toBe('Reference Farm');

    const badgeRows = fixture.nativeElement.querySelectorAll('.farm-list__reference-badge');
    expect(badgeRows[0].textContent?.trim()).toBe('');
    expect(badgeRows[1].textContent?.trim()).toBe('Reference');
  });

  it('sets title attribute on card body link for full farm name', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const bodyLink = fixture.nativeElement.querySelector('.farm-list__card-body') as HTMLAnchorElement;
    expect(bodyLink.getAttribute('title')).toBe('User Farm');
  });

  it('action buttons use .btn base class with variant modifiers', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [
        {
          id: 1,
          name: 'User Farm',
          region: 'jp',
          latitude: 35.6895,
          longitude: 139.6917,
          weather_data_status: 'completed' as const,
          is_reference: false
        }
      ],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const primary = fixture.nativeElement.querySelector('.section-card__header-actions .btn-primary') as HTMLElement;
    const secondary = fixture.nativeElement.querySelector('.item-card__actions .btn-secondary') as HTMLElement;
    const danger = fixture.nativeElement.querySelector('.item-card__actions .btn-danger') as HTMLElement;

    expect(primary).toBeTruthy();
    expect(secondary).toBeTruthy();
    expect(danger).toBeTruthy();
    for (const el of [primary, secondary, danger]) {
      expect(el.classList.contains('btn')).toBe(true);
    }
  });

  it('shows card-list skeleton while loading', () => {
    component.control = {
      loading: true,
      error: null,
      farms: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-card-list-skeleton')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.master-loading:not(.list-loading-text)')).toBeNull();
  });

  it('shows error alert with retry button that reloads the farm list', () => {
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      farms: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.page-alert-error[role="alert"]');
    expect(alert).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-card-list-skeleton')).toBeNull();
    expect(fixture.nativeElement.querySelector('.section-card__header-actions')).toBeNull();

    const retryBtn = fixture.nativeElement.querySelector('.master-list__retry') as HTMLButtonElement;
    expect(retryBtn).toBeTruthy();

    loadUseCase.execute.mockClear();
    retryBtn.click();
    expect(loadUseCase.execute).toHaveBeenCalled();
  });
});