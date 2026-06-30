import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { PrivatePlanCreateGateway } from '../private-plan-create/private-plan-create-gateway';
import { PlanGateway } from '../plans/plan-gateway';
import { EnsurePlanForFarmOutputPort } from './ensure-plan-for-farm.output-port';

describe('EnsurePlanForFarmUseCase', () => {
  it('returns existing plan id without calling create', () => {
    const createPlan = vi.fn();
    const onSuccess = vi.fn();
    const outputPort: EnsurePlanForFarmOutputPort = {
      onSuccess,
      onError: vi.fn()
    };

    const useCase = new EnsurePlanForFarmUseCase(
      outputPort,
      { createPlan } as unknown as PrivatePlanCreateGateway,
      { listPlans: vi.fn() } as unknown as PlanGateway
    );

    useCase.execute({ farmId: 10, existingPlanId: 42 });

    expect(createPlan).not.toHaveBeenCalled();
    expect(onSuccess).toHaveBeenCalledWith({ planId: 42, created: false });
  });

  it('creates a plan when none exists', () => {
    const createPlan = vi.fn(() => of({ id: 99 }));
    const onSuccess = vi.fn();
    const outputPort: EnsurePlanForFarmOutputPort = {
      onSuccess,
      onError: vi.fn()
    };

    const useCase = new EnsurePlanForFarmUseCase(
      outputPort,
      { createPlan } as unknown as PrivatePlanCreateGateway,
      { listPlans: vi.fn() } as unknown as PlanGateway
    );

    useCase.execute({ farmId: 10, existingPlanId: null });

    expect(createPlan).toHaveBeenCalledWith({ farmId: 10 });
    expect(onSuccess).toHaveBeenCalledWith({ planId: 99, created: true });
  });

  it('resolves plan id from list when create returns plan_already_exists', () => {
    const createPlan = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'plans.errors.plan_already_exists_annual' }
          })
      )
    );
    const listPlans = vi.fn(() => of([{ id: 77, name: 'Plan', farm_id: 10 }]));
    const onSuccess = vi.fn();
    const outputPort: EnsurePlanForFarmOutputPort = {
      onSuccess,
      onError: vi.fn()
    };

    const useCase = new EnsurePlanForFarmUseCase(
      outputPort,
      { createPlan } as unknown as PrivatePlanCreateGateway,
      { listPlans } as unknown as PlanGateway
    );

    useCase.execute({ farmId: 10, existingPlanId: null });

    expect(listPlans).toHaveBeenCalled();
    expect(onSuccess).toHaveBeenCalledWith({ planId: 77, created: false });
  });

  it('reports i18n key on create failure', () => {
    const createPlan = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'plans.errors.no_fields_in_farm' }
          })
      )
    );
    const onError = vi.fn();
    const outputPort: EnsurePlanForFarmOutputPort = {
      onSuccess: vi.fn(),
      onError
    };

    const useCase = new EnsurePlanForFarmUseCase(
      outputPort,
      { createPlan } as unknown as PrivatePlanCreateGateway,
      { listPlans: vi.fn() } as unknown as PlanGateway
    );

    useCase.execute({ farmId: 10, existingPlanId: null });

    expect(onError).toHaveBeenCalledWith({ message: 'plans.errors.no_fields_in_farm' });
  });

  it('reports not_found when plan_already_exists but list has no match', () => {
    const createPlan = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'plans.errors.plan_already_exists_annual' }
          })
      )
    );
    const listPlans = vi.fn(() => of([]));
    const onError = vi.fn();
    const outputPort: EnsurePlanForFarmOutputPort = {
      onSuccess: vi.fn(),
      onError
    };

    const useCase = new EnsurePlanForFarmUseCase(
      outputPort,
      { createPlan } as unknown as PrivatePlanCreateGateway,
      { listPlans } as unknown as PlanGateway
    );

    useCase.execute({ farmId: 10, existingPlanId: null });

    expect(onError).toHaveBeenCalledWith({ message: 'plans.errors.not_found' });
  });
});
