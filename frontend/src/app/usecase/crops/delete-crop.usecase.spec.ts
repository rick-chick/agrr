import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { DeleteCropUseCase } from './delete-crop.usecase';
import { CropGateway } from './crop-gateway';
import { DeleteCropOutputPort } from './delete-crop.output-port';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('DeleteCropUseCase', () => {
  it('calls outputPort.onSuccess with deletedCropId and undo when gateway returns', () => {
    const undoResponse: DeletionUndoResponse = {
      undo_token: 'token-1',
      toast_message: 'Deleted',
      undo_path: '/undo/token-1'
    };
    const gateway: CropGateway = {
      list: () => of([]),
      show: () => of({} as never),
      create: () => of({} as never),
      update: () => of({} as never),
      destroy: vi.fn(() => of(undoResponse))
    };

    let receivedDto: { deletedCropId: number; undo?: DeletionUndoResponse } | null = null;
    const outputPort: DeleteCropOutputPort = {
      onSuccess: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new DeleteCropUseCase(outputPort, gateway);
    useCase.execute({ cropId: 2 });

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.deletedCropId).toBe(2);
    expect(receivedDto!.undo).toEqual(undoResponse);
    expect(gateway.destroy).toHaveBeenCalledWith(2);
  });

  it('calls outputPort.onError with err.message when gateway throws generic Error', () => {
    const gateway: CropGateway = {
      list: () => of([]),
      show: () => of({} as never),
      create: () => of({} as never),
      update: () => of({} as never),
      destroy: () => throwError(() => new Error('network error'))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: DeleteCropOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new DeleteCropUseCase(outputPort, gateway);
    useCase.execute({ cropId: 2 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toContain('network error');
  });

  it('calls outputPort.onError with err.error.error when API returns 422 with body.error (server message)', () => {
    const serverMessage = 'この作物は作付け計画で使用されているため削除できません。まず作付け計画から削除してください。';
    const gateway: CropGateway = {
      list: () => of([]),
      show: () => of({} as never),
      create: () => of({} as never),
      update: () => of({} as never),
      destroy: () =>
        throwError(() => ({
          message: 'Http failure response for ...: 422 Unprocessable Content',
          error: { error: serverMessage }
        }))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: DeleteCropOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new DeleteCropUseCase(outputPort, gateway);
    useCase.execute({ cropId: 2 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe(serverMessage);
  });
});
