import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage } from '../../core/api-error-message';
import { DeleteFieldInputPort } from './delete-field.input-port';
import { DeleteFieldOutputPort, DELETE_FIELD_OUTPUT_PORT } from './delete-field.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';
import { DeleteFieldInputDto } from './delete-field.dtos';

@Injectable()
export class DeleteFieldUseCase implements DeleteFieldInputPort {
  constructor(
    @Inject(DELETE_FIELD_OUTPUT_PORT) private readonly outputPort: DeleteFieldOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: DeleteFieldInputDto): void {
    this.farmGateway.destroyField(dto.fieldId).subscribe({
      next: (undo) => this.outputPort.present({ undo, farmId: dto.farmId }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorMessage(err) })
    });
  }
}