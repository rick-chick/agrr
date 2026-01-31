import { Inject, Injectable } from '@angular/core';
import { UpdateNutrientRequirementInputPort } from './update-nutrient-requirement.input-port';
import { UpdateNutrientRequirementOutputPort, UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT } from './update-nutrient-requirement.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { UpdateNutrientRequirementInputDto } from './update-nutrient-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class UpdateNutrientRequirementUseCase implements UpdateNutrientRequirementInputPort {
  constructor(
    @Inject(UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT) private readonly outputPort: UpdateNutrientRequirementOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: UpdateNutrientRequirementInputDto): void {
    // First check if requirement exists
    this.cropStageGateway.getNutrientRequirement(dto.cropId, dto.stageId).subscribe({
      next: (existingRequirement) => {
        if (existingRequirement) {
          // Update existing requirement
          this.cropStageGateway.updateNutrientRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError(new ErrorDto(err.message))
          });
        } else {
          // Create new requirement
          this.cropStageGateway.createNutrientRequirement(dto.cropId, dto.stageId, dto.payload).subscribe({
            next: (requirement) => this.outputPort.present({ requirement }),
            error: (err) => this.outputPort.onError(new ErrorDto(err.message))
          });
        }
      },
      error: (err) => this.outputPort.onError(new ErrorDto(err.message))
    });
  }
}