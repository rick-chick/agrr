import { Inject, Injectable } from '@angular/core';
import { CreateFieldInputPort } from './create-field.input-port';
import { CreateFieldOutputPort, CREATE_FIELD_OUTPUT_PORT } from './create-field.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';
import { CreateFieldInputDto, CreateFieldOutputDto } from './create-field.dtos';

@Injectable()
export class CreateFieldUseCase implements CreateFieldInputPort {
  constructor(
    @Inject(CREATE_FIELD_OUTPUT_PORT) private readonly outputPort: CreateFieldOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: CreateFieldInputDto): void {
    this.farmGateway.createField(dto.farmId, dto.payload).subscribe({
      next: (field) => this.outputPort.present({ field, farmId: dto.farmId }),
      error: (err) => this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}