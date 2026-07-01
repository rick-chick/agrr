import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { CreatePrivatePlanPresenter } from './create-private-plan.presenter';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { Router } from '@angular/router';
import { PlanNewView, PlanNewViewState } from '../../components/plans/plan-new.view';

describe('CreatePrivatePlanPresenter', () => {
  let presenter: CreatePrivatePlanPresenter;
  let view: PlanNewView;
  let lastControl: PlanNewViewState | null;
  let mockRouter: Router & { navigate: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockRouter = { navigate: vi.fn() } as Router & { navigate: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        CreatePrivatePlanPresenter,
        { provide: Router, useValue: mockRouter }
      ]
    });
    presenter = TestBed.inject(CreatePrivatePlanPresenter);

    lastControl = null;
    view = {
      get control(): PlanNewViewState {
        return lastControl ?? {
          loading: true,
          submitting: false,
          error: null,
          farms: [],
          selectedFarmId: null,
          noFieldsWarning: false,
          pendingErrorFlash: null,
          pendingSuccessFlash: null
        };
      },
      set control(value: PlanNewViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('CreatePrivatePlanOutputPort', () => {
    it('queues pending success flash and navigates to plan detail on present(dto)', () => {
      const dto: CreatePrivatePlanResponseDto = { id: 123 };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'plans.messages.plan_created'
      });
      expect(mockRouter.navigate).toHaveBeenCalledTimes(1);
      expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans', 123]);
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
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

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Validation error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
    });
  });
});
