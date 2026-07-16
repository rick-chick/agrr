import { Inject, Injectable } from '@angular/core';
import { concatMap, from, Observable, of } from 'rxjs';
import { catchError, last, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { Crop } from '../../domain/crops/crop';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import {
  upsertNutrientRequirement,
  upsertSunshineRequirement,
  upsertTemperatureRequirement
} from './crop-stage-requirement-gateway-ops';
import { SaveCropStageAdvancedDetailsInputDto } from './save-crop-stage-advanced-details.dtos';
import { SaveCropStageAdvancedDetailsInputPort } from './save-crop-stage-advanced-details.input-port';
import {
  SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT,
  SaveCropStageAdvancedDetailsOutputPort
} from './save-crop-stage-advanced-details.output-port';

type AdvancedSaveStep = Observable<unknown>;

@Injectable()
export class SaveCropStageAdvancedDetailsUseCase implements SaveCropStageAdvancedDetailsInputPort {
  constructor(
    @Inject(SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT)
    private readonly outputPort: SaveCropStageAdvancedDetailsOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: SaveCropStageAdvancedDetailsInputDto): void {
    const steps = this.buildSteps(dto);
    if (steps.length === 0) {
      return;
    }

    from(steps)
      .pipe(
        concatMap((step) => step),
        last(),
        switchMap(() => this.reloadCrop(dto.cropId)),
        catchError((err: unknown) =>
          this.reloadCrop(dto.cropId).pipe(
            map((crop) => {
              this.outputPort.onAdvancedPartialFailure({ crop, stageId: dto.stageId });
              return null;
            }),
            catchError(() => {
              this.outputPort.onError({ message: apiErrorI18nKey(err) });
              return of(null);
            })
          )
        )
      )
      .subscribe((crop) => {
        if (!crop) {
          return;
        }
        const stage = crop.crop_stages?.find((item) => item.id === dto.stageId);
        if (!stage) {
          this.outputPort.onError({ message: 'crops.flash.not_found' });
          return;
        }
        this.outputPort.onSuccess({ stage });
      });
  }

  private buildSteps(dto: SaveCropStageAdvancedDetailsInputDto): AdvancedSaveStep[] {
    const steps: AdvancedSaveStep[] = [];
    if (dto.sunshinePatch && Object.keys(dto.sunshinePatch).length > 0) {
      steps.push(upsertSunshineRequirement(this.cropStageGateway, dto.cropId, dto.stageId, dto.sunshinePatch));
    }
    if (dto.nutrientPatch && Object.keys(dto.nutrientPatch).length > 0) {
      steps.push(upsertNutrientRequirement(this.cropStageGateway, dto.cropId, dto.stageId, dto.nutrientPatch));
    }
    if (dto.temperaturePatch && Object.keys(dto.temperaturePatch).length > 0) {
      steps.push(upsertTemperatureRequirement(this.cropStageGateway, dto.cropId, dto.stageId, dto.temperaturePatch));
    }
    return steps;
  }

  private reloadCrop(cropId: number): Observable<Crop> {
    return this.cropGateway.show(cropId);
  }
}
