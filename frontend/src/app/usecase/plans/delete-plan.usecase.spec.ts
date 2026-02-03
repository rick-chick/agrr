import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { DeletePlanUseCase } from './delete-plan.usecase';
import { PlanGateway } from './plan-gateway';
import { DeletePlanOutputPort } from './delete-plan.output-port';
import { DeletePlanSuccessDto } from './delete-plan.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('DeletePlanUseCase', () => {
  const createGateway = (deletePlan: (planId: number) => unknown): PlanGateway =>
    ({
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({} as never),
      deletePlan
    } as PlanGateway);

  it('calls deletePlan and forwards success metadata and callbacks', () => {
    const undoResponse: DeletionUndoResponse = {
      undo_token: 'token-1',
      toast_message: 'プラン Foo を削除しました',
      undo_path: '/undo_deletion?undo_token=token-1',
      undo_deadline: '2026-02-03T12:00:00Z',
      resource: 'Foo',
      resource_dom_id: 'cultivation_plan_8',
      redirect_path: '/plans',
      auto_hide_after: 60000
    };
    const deletePlan = vi.fn((planId: number) => of(undoResponse));
    const gateway: PlanGateway = createGateway(deletePlan);

    const onSuccessCallback = vi.fn();
    const onAfterUndoCallback = vi.fn();
    let receivedDto: DeletePlanSuccessDto | null = null;
    const outputPort: DeletePlanOutputPort = {
      onSuccess: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new DeletePlanUseCase(outputPort, gateway);
    useCase.execute({
      planId: 8,
      onSuccess: onSuccessCallback,
      onAfterUndo: onAfterUndoCallback
    });

    expect(deletePlan).toHaveBeenCalledWith(8);
    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.deletedPlanId).toBe(8);
    expect(receivedDto!.undo).toEqual(undoResponse);
    receivedDto!.refresh?.();
    expect(onAfterUndoCallback).toHaveBeenCalled();
    expect(onSuccessCallback).toHaveBeenCalled();
  });

  it('calls outputPort.onError with err.message when gateway throws generic Error', () => {
    const gateway: PlanGateway = createGateway((planId: number) => throwError(() => new Error('network error')));

    let receivedError: { message: string; scope?: string } | null = null;
    const outputPort: DeletePlanOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new DeletePlanUseCase(outputPort, gateway);
    useCase.execute({ planId: 8 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toContain('network error');
    expect(receivedError!.scope).toBe('delete-plan');
  });

  it('calls outputPort.onError with err.error.error when API returns 422 with body.error (server message)', () => {
    const serverMessage = 'このプランは削除できません。';
    const gateway: PlanGateway = createGateway((planId: number) =>
      throwError(() => ({
        message: 'Http failure response for ...: 422 Unprocessable Content',
        error: { error: serverMessage }
      }))
    );

    let receivedError: { message: string; scope?: string } | null = null;
    const outputPort: DeletePlanOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new DeletePlanUseCase(outputPort, gateway);
    useCase.execute({ planId: 8 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe(serverMessage);
    expect(receivedError!.scope).toBe('delete-plan');
  });

  it('calls outputPort.onError with err.error.errors when API returns 422 with body.errors array', () => {
    const serverErrors = ['Error 1', 'Error 2'];
    const gateway: PlanGateway = createGateway((planId: number) =>
      throwError(() => ({
        message: 'Http failure response for ...: 422 Unprocessable Content',
        error: { errors: serverErrors }
      }))
    );

    let receivedError: { message: string; scope?: string } | null = null;
    const outputPort: DeletePlanOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new DeletePlanUseCase(outputPort, gateway);
    useCase.execute({ planId: 8 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Error 1, Error 2');
    expect(receivedError!.scope).toBe('delete-plan');
  });

});
