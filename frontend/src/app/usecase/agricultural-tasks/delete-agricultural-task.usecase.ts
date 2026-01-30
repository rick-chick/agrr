import { Inject, Injectable } from '@angular/core';
import { DeleteAgriculturalTaskInputDto } from './delete-agricultural-task.dtos';
import { DeleteAgriculturalTaskInputPort } from './delete-agricultural-task.input-port';
import {
  DeleteAgriculturalTaskOutputPort,
  DELETE_AGRICULTURAL_TASK_OUTPUT_PORT
} from './delete-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY, AgriculturalTaskGateway } from './agricultural-task-gateway';

@Injectable()
export class DeleteAgriculturalTaskUseCase implements DeleteAgriculturalTaskInputPort {
  constructor(
    @Inject(DELETE_AGRICULTURAL_TASK_OUTPUT_PORT) private readonly outputPort: DeleteAgriculturalTaskOutputPort,
    @Inject(AGRICULTURAL_TASK_GATEWAY) private readonly agriculturalTaskGateway: AgriculturalTaskGateway
  ) {}

  execute(dto: DeleteAgriculturalTaskInputDto): void {
    this.agriculturalTaskGateway.destroy(dto.agriculturalTaskId).subscribe({
      next: (response) => {
        this.outputPort.onSuccess({
          deletedAgriculturalTaskId: dto.agriculturalTaskId,
          undo: response,
          refresh: dto.onAfterUndo
        });
        dto.onSuccess?.();
      },
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}