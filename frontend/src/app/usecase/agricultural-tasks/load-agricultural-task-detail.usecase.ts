import { Inject, Injectable } from '@angular/core';
import { LoadAgriculturalTaskDetailInputDto } from './load-agricultural-task-detail.dtos';
import { LoadAgriculturalTaskDetailInputPort } from './load-agricultural-task-detail.input-port';
import {
  LoadAgriculturalTaskDetailOutputPort,
  LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT
} from './load-agricultural-task-detail.output-port';
import { AGRICULTURAL_TASK_GATEWAY, AgriculturalTaskGateway } from './agricultural-task-gateway';

@Injectable()
export class LoadAgriculturalTaskDetailUseCase implements LoadAgriculturalTaskDetailInputPort {
  constructor(
    @Inject(LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadAgriculturalTaskDetailOutputPort,
    @Inject(AGRICULTURAL_TASK_GATEWAY) private readonly agriculturalTaskGateway: AgriculturalTaskGateway
  ) {}

  execute(dto: LoadAgriculturalTaskDetailInputDto): void {
    this.agriculturalTaskGateway.show(dto.agriculturalTaskId).subscribe({
      next: (agriculturalTask) => this.outputPort.present({ agriculturalTask }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}