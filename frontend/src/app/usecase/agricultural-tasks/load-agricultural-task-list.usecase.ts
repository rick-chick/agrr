import { Inject, Injectable } from '@angular/core';
import { LoadAgriculturalTaskListInputPort } from './load-agricultural-task-list.input-port';
import {
  LoadAgriculturalTaskListOutputPort,
  LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT
} from './load-agricultural-task-list.output-port';
import {
  AGRICULTURAL_TASK_GATEWAY,
  AgriculturalTaskGateway
} from './agricultural-task-gateway';

@Injectable()
export class LoadAgriculturalTaskListUseCase implements LoadAgriculturalTaskListInputPort {
  constructor(
    @Inject(LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT)
    private readonly outputPort: LoadAgriculturalTaskListOutputPort,
    @Inject(AGRICULTURAL_TASK_GATEWAY)
    private readonly agriculturalTaskGateway: AgriculturalTaskGateway
  ) {}

  execute(): void {
    this.agriculturalTaskGateway.list().subscribe({
      next: (tasks) => this.outputPort.present({ tasks }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
