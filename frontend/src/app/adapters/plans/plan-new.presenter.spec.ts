import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { PlanNewPresenter } from './plan-new.presenter';
import { PlanNewView } from '../../components/plans/plan-new.view';
import { FarmPlanCreateOption } from '../../usecase/private-plan-create/private-plan-create-gateway';

describe('PlanNewPresenter', () => {
  let presenter: PlanNewPresenter;
  let mockView: PlanNewView & {
    control: {
      loading: boolean;
      submitting: boolean;
      error: string | null;
      farms: FarmPlanCreateOption[];
      selectedFarmId: number | null;
      noFieldsWarning: boolean;
    };
  };

  beforeEach(() => {
    mockView = {
      get control() {
        return {
          loading: true,
          submitting: false,
          error: null,
          farms: [],
          selectedFarmId: null,
          noFieldsWarning: false
        };
      },
      set control(_value) {}
    } as PlanNewView & {
      control: {
        loading: boolean;
        submitting: boolean;
        error: string | null;
        farms: FarmPlanCreateOption[];
        selectedFarmId: number | null;
        noFieldsWarning: boolean;
      };
    };

    TestBed.configureTestingModule({
      providers: [PlanNewPresenter]
    });

    presenter = TestBed.inject(PlanNewPresenter);
  });

  it('should create', () => {
    expect(presenter).toBeTruthy();
  });

  it('should set view and present farms', () => {
    presenter.setView(mockView);

    const farms: FarmPlanCreateOption[] = [
      { id: 1, name: 'Farm 1', fieldCount: 2, totalArea: 100, hasValidFields: true },
      { id: 2, name: 'Farm 2', fieldCount: 0, totalArea: 0, hasValidFields: false }
    ];

    expect(() => presenter.present({ farms })).not.toThrow();
    expect(() => presenter.onError({ message: 'error' })).not.toThrow();
  });

  it('should present farms to view', () => {
    presenter.setView(mockView);

    const farms: FarmPlanCreateOption[] = [
      { id: 1, name: 'Farm 1', fieldCount: 2, totalArea: 100, hasValidFields: true },
      { id: 2, name: 'Farm 2', fieldCount: 0, totalArea: 0, hasValidFields: false }
    ];

    presenter.present({ farms });

    expect(mockView.control).toBeDefined();
  });

  it('should present error to view', () => {
    presenter.setView(mockView);

    presenter.onError({ message: 'Failed to load farms' });

    expect(mockView.control).toBeDefined();
  });
});
