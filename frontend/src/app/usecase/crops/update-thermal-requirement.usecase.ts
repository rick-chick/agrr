import { Inject, Injectable } from '@angular/core';
import { UpdateThermalRequirementInputPort } from './update-thermal-requirement.input-port';
import { UpdateThermalRequirementOutputPort, UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT } from './update-thermal-requirement.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { UpdateThermalRequirementInputDto } from './update-thermal-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class UpdateThermalRequirementUseCase implements UpdateThermalRequirementInputPort {
  constructor(
    @Inject(UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT) private readonly outputPort: UpdateThermalRequirementOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: UpdateThermalRequirementInputDto): void {
    // First check if requirement exists
    this.cropStageGateway.getThermalRequirement(dto.cropId, dto.stageId).subscribe({
      next: (existingRequirement) => {
        if (existingRequirement) {
          // Update existing requirement
          this.cropStageGateway.updateThermalRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        } else {
          // Create new requirement
          this.cropStageGateway.createThermalRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        }
      },
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}