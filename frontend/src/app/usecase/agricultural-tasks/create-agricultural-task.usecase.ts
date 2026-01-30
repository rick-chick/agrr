import { Inject, Injectable } from '@angular/core';
import { CreateAgriculturalTaskInputDto } from './create-agricultural-task.dtos';
import { CreateAgriculturalTaskInputPort } from './create-agricultural-task.input-port';
import {
  CreateAgriculturalTaskOutputPort,
  CREATE_AGRICULTURAL_TASK_OUTPUT_PORT
} from './create-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY, AgriculturalTaskGateway } from './agricultural-task-gateway';

@Injectable()
export class CreateAgriculturalTaskUseCase implements CreateAgriculturalTaskInputPort {
  constructor(
    @Inject(CREATE_AGRICULTURAL_TASK_OUTPUT_PORT) private readonly outputPort: CreateAgriculturalTaskOutputPort,
    @Inject(AGRICULTURAL_TASK_GATEWAY) private readonly agriculturalTaskGateway: AgriculturalTaskGateway
  ) {}

  execute(dto: CreateAgriculturalTaskInputDto): void {
    this.agriculturalTaskGateway
      .create({
        name: dto.name,
        description: dto.description,
        time_per_sqm: dto.time_per_sqm,
        weather_dependency: dto.weather_dependency,
        required_tools: dto.required_tools ?? [],
        skill_level: dto.skill_level,
        region: dto.region,
        task_type: dto.task_type
      })
      .subscribe({
        next: (agriculturalTask) => {
          this.outputPort.onSuccess({ agriculturalTask });
          dto.onSuccess?.(agriculturalTask);
        },
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}