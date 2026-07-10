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
    const translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('en', {
      farms: {
        index: {
          reference_badge: 'Reference'
        }
      }
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

  it('calls deleteUseCase.execute with farmId on deleteFarm', () => {
    const farmId = 123;
    component.deleteFarm(farmId);
    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      farmId,
      onAfterUndo: expect.any(Function)
    });
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

  it('displays reference farms with (参照) indicator', () => {
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
    const normalizeText = (value: string | null) => value?.replace(/\s+/g, ' ').trim() ?? '';
    expect(normalizeText(farmTitles[0].textContent)).toBe('User Farm');
    expect(normalizeText(farmTitles[1].textContent)).toBe('Reference Farm (Reference)');
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
});