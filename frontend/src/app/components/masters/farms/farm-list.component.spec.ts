import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmListComponent } from './farm-list.component';
import { LoadFarmListUseCase } from '../../../usecase/farms/load-farm-list.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { FarmListPresenter } from '../../../adapters/farms/farm-list.presenter';
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

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmListViewState = {
      loading: false,
      error: null,
      farms: []
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmListViewState = {
      loading: false,
      error: null,
      farms: []
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
});