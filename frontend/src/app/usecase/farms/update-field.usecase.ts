import { Inject, Injectable } from '@angular/core';
import { UpdateFieldInputPort } from './update-field.input-port';
import { UpdateFieldOutputPort, UPDATE_FIELD_OUTPUT_PORT } from './update-field.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';
import { UpdateFieldInputDto, UpdateFieldOutputDto } from './update-field.dtos';

@Injectable()
export class UpdateFieldUseCase implements UpdateFieldInputPort {
  constructor(
    @Inject(UPDATE_FIELD_OUTPUT_PORT) private readonly outputPort: UpdateFieldOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: UpdateFieldInputDto): void {
    this.farmGateway.updateField(dto.fieldId, dto.payload).subscribe({
      next: (field) => this.outputPort.present({ field }),
      error: (err) => this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}