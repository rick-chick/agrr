import { TestBed } from '@angular/core/testing';
import { CreatePrivatePlanPresenter } from './create-private-plan.presenter';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanNewView, PlanNewViewState } from '../../components/plans/plan-new.view';

const emptyPlanNewControl = (): PlanNewViewState => ({
  loading: true,
  submitting: false,
  error: null,
  farms: [],
  selectedFarmId: null,
  noFieldsWarning: false,
  carryoverEnabled: false,
  sourcePlans: [],
  selectedSourcePlanId: null,
  carryoverPreviewLoading: false,
  carryoverPreviewError: null,
  carryoverPreview: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingNavigation: null
});

describe('CreatePrivatePlanPresenter', () => {
  let presenter: CreatePrivatePlanPresenter;
  let view: PlanNewView;
  let lastControl: PlanNewViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CreatePrivatePlanPresenter]
    });
    presenter = TestBed.inject(CreatePrivatePlanPresenter);

    lastControl = null;
    view = {
      get control(): PlanNewViewState {
        return lastControl ?? emptyPlanNewControl();
      },
      set control(value: PlanNewViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('CreatePrivatePlanOutputPort', () => {
    it('queues pending success flash and navigation to plan detail on present(dto)', () => {
      const dto: CreatePrivatePlanResponseDto = { id: 123 };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'plans.messages.plan_created'
      });
      expect(lastControl!.pendingNavigation).toEqual({
        commands: ['/plans', 123]
      });
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
    });

    it('navigates to learn with imported snapshot expand when navigateToLearnAfterCreate is true', () => {
      const dto: CreatePrivatePlanResponseDto = { id: 123, navigateToLearnAfterCreate: true };

      presenter.present(dto);

      expect(lastControl!.pendingNavigation).toEqual({
        commands: ['/plans', 123, 'learn'],
        extras: { queryParams: { expand: 'imported_snapshot' } }
      });
    });

    it('queues pending error flash and updates view.control on onError(dto)', () => {
      const initialControl: PlanNewViewState = emptyPlanNewControl();
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
