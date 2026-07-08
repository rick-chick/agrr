import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { WorkHubInitUseCase } from './work-hub-init.usecase';
import { WorkHubGateway } from './work-hub-gateway';
import { WorkHubInitOutputPort } from './work-hub-init.output-port';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';

describe('WorkHubInitUseCase', () => {
  it('presents farms when multiple farms exist', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm 1',
            fieldCount: 2,
            totalArea: 80,
            hasValidFields: true,
            planId: 9
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: null
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };
    const ensureExecute = vi.fn();

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      { execute: ensureExecute } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalled();
    expect(ensureExecute).not.toHaveBeenCalled();
  });

  it('auto-ensures when a single valid farm exists', () => {
    const farms = [
      {
        farmId: 5,
        farmName: 'Solo Farm',
        fieldCount: 1,
        totalArea: 50,
        hasValidFields: true,
        planId: 9
      }
    ];
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => of(farms)
    };
    const beginEnsure = vi.fn();
    const present = vi.fn();
    const ensureExecute = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      { execute: ensureExecute } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({ farms });
    expect(beginEnsure).toHaveBeenCalled();
    expect(ensureExecute).toHaveBeenCalledWith({ farmId: 5, existingPlanId: 9 });
  });

  it('presents a single farm without valid fields', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 5,
            farmName: 'Solo Farm',
            fieldCount: 0,
            totalArea: 0,
            hasValidFields: false,
            planId: null
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({
          farmId: 5,
          hasValidFields: false
        })
      ]
    });
  });

  it('forwards load errors to output port', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => throwError(() => new Error('common.api_error.generic'))
    };
    const onError = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present: vi.fn(),
      onError,
      beginEnsure: vi.fn()
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
  });
});
