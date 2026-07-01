import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { PlanNewPresenter } from './plan-new.presenter';
import { PlanNewView, PlanNewViewState } from '../../components/plans/plan-new.view';
import { FarmPlanCreateOption } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

describe('PlanNewPresenter', () => {
  let presenter: PlanNewPresenter;
  let view: PlanNewView;
  let lastControl: PlanNewViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanNewPresenter]
    });

    presenter = TestBed.inject(PlanNewPresenter);

    lastControl = null;
    view = {
      get control(): PlanNewViewState {
        return (
          lastControl ?? {
            loading: true,
            submitting: false,
            error: null,
            farms: [],
            selectedFarmId: null,
            noFieldsWarning: false,
            pendingErrorFlash: null,
            pendingSuccessFlash: null
          }
        );
      },
      set control(value: PlanNewViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('should create', () => {
    expect(presenter).toBeTruthy();
  });

  it('updates view.control on present(dto)', () => {
    const farms: FarmPlanCreateOption[] = [
      { id: 1, name: 'Farm 1', fieldCount: 2, totalArea: 100, hasValidFields: true },
      { id: 2, name: 'Farm 2', fieldCount: 0, totalArea: 0, hasValidFields: false }
    ];

    presenter.present({ farms });

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.farms).toEqual(farms);
    expect(lastControl!.selectedFarmId).toBeNull();
    expect(lastControl!.noFieldsWarning).toBe(false);
    expect(lastControl!.pendingErrorFlash).toBeNull();
  });

  it('queues pending error flash and updates view.control on onError(dto)', () => {
    const initialControl: PlanNewViewState = {
      loading: true,
      submitting: false,
      error: null,
      farms: [],
      selectedFarmId: null,
      noFieldsWarning: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
    lastControl = initialControl;

    const dto: ErrorDto = { message: 'Failed to load farms' };

    presenter.onError(dto);

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.farms).toEqual([]);
    expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Failed to load farms' });
  });
});
