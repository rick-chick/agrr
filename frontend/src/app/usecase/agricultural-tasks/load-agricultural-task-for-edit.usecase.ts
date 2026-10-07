import { Inject, Injectable } from '@angular/core';
import { LoadAgriculturalTaskForEditInputDto } from './load-agricultural-task-for-edit.dtos';
import { LoadAgriculturalTaskForEditInputPort } from './load-agricultural-task-for-edit.input-port';
import {
  LoadAgriculturalTaskForEditOutputPort,
  LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT
} from './load-agricultural-task-for-edit.output-port';
import { AGRICULTURAL_TASK_GATEWAY, AgriculturalTaskGateway } from './agricultural-task-gateway';

@Injectable()
export class LoadAgriculturalTaskForEditUseCase implements LoadAgriculturalTaskForEditInputPort {
  constructor(
    @Inject(LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadAgriculturalTaskForEditOutputPort,
    @Inject(AGRICULTURAL_TASK_GATEWAY) private readonly agriculturalTaskGateway: AgriculturalTaskGateway
  ) {}

  execute(dto: LoadAgriculturalTaskForEditInputDto): void {
    this.agriculturalTaskGateway.show(dto.agriculturalTaskId).subscribe({
      next: (agriculturalTask) => this.outputPort.present({ agriculturalTask }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}