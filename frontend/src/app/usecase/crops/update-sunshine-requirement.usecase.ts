import { Inject, Injectable } from '@angular/core';
import { UpdateSunshineRequirementInputPort } from './update-sunshine-requirement.input-port';
import { UpdateSunshineRequirementOutputPort, UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT } from './update-sunshine-requirement.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { UpdateSunshineRequirementInputDto } from './update-sunshine-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class UpdateSunshineRequirementUseCase implements UpdateSunshineRequirementInputPort {
  constructor(
    @Inject(UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT) private readonly outputPort: UpdateSunshineRequirementOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: UpdateSunshineRequirementInputDto): void {
    // First check if requirement exists
    this.cropStageGateway.getSunshineRequirement(dto.cropId, dto.stageId).subscribe({
      next: (existingRequirement) => {
        if (existingRequirement) {
          // Update existing requirement
          this.cropStageGateway.updateSunshineRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        } else {
          // Create new requirement
          this.cropStageGateway.createSunshineRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError({ message: err.message })
          });
        }
      },
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}