import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { FarmListComponent } from './farm-list.component';
import { LoadFarmListUseCase } from '../../../usecase/farms/load-farm-list.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { FarmListPresenter } from '../../../adapters/farms/farm-list.presenter';
import { FarmListViewState } from './farm-list.view';

describe('FarmListComponent', () => {
  let component: FarmListComponent;
  let fixture: ComponentFixture<FarmListComponent>;
  let loadUseCase: { execute: jest.Mock };
  let deleteUseCase: { execute: jest.Mock };
  let presenter: { setView: jest.Mock };
  let cdr: { markForCheck: jest.Mock };

  beforeEach(async () => {
    loadUseCase = { execute: jest.fn() };
    deleteUseCase = { execute: jest.fn() };
    presenter = { setView: jest.fn() };
    cdr = { markForCheck: jest.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmListComponent],
      providers: [
        { provide: LoadFarmListUseCase, useValue: loadUseCase },
        { provide: DeleteFarmUseCase, useValue: deleteUseCase },
        { provide: FarmListPresenter, useValue: presenter },
        { provide: Router, useValue: {} }
      ]
    }).compileComponents();

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
    expect(deleteUseCase.execute).toHaveBeenCalledWith({ farmId });
  });

  it('ngOnInit sets view on presenter and calls load', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalled();
  });
});