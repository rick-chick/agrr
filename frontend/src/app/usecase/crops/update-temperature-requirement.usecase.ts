import { Inject, Injectable } from '@angular/core';
import { UpdateTemperatureRequirementInputPort } from './update-temperature-requirement.input-port';
import { UpdateTemperatureRequirementOutputPort, UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT } from './update-temperature-requirement.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { UpdateTemperatureRequirementInputDto } from './update-temperature-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class UpdateTemperatureRequirementUseCase implements UpdateTemperatureRequirementInputPort {
  constructor(
    @Inject(UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT) private readonly outputPort: UpdateTemperatureRequirementOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: UpdateTemperatureRequirementInputDto): void {
    // First check if requirement exists
    this.cropStageGateway.getTemperatureRequirement(dto.cropId, dto.stageId).subscribe({
      next: (existingRequirement) => {
        if (existingRequirement) {
          // Update existing requirement
          this.cropStageGateway.updateTemperatureRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        } else {
          // Create new requirement
          this.cropStageGateway.createTemperatureRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        }
      },
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}