import { Inject, Injectable } from '@angular/core';
import { concatMap, from, Observable, of } from 'rxjs';
import { catchError, last, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { Crop } from '../../domain/crops/crop';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import {
  upsertTemperatureRequirement,
  upsertThermalRequirement
} from './crop-stage-requirement-gateway-ops';
import { SaveCropStagePanelInputDto } from './save-crop-stage-panel.dtos';
import { SaveCropStagePanelInputPort } from './save-crop-stage-panel.input-port';
import {
  SAVE_CROP_STAGE_PANEL_OUTPUT_PORT,
  SaveCropStagePanelOutputPort
} from './save-crop-stage-panel.output-port';

type PanelSaveStep = Observable<unknown>;

@Injectable()
export class SaveCropStagePanelUseCase implements SaveCropStagePanelInputPort {
  constructor(
    @Inject(SAVE_CROP_STAGE_PANEL_OUTPUT_PORT)
    private readonly outputPort: SaveCropStagePanelOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: SaveCropStagePanelInputDto): void {
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
              this.outputPort.onPanelPartialFailure({ crop, stageId: dto.stageId });
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

  private buildSteps(dto: SaveCropStagePanelInputDto): PanelSaveStep[] {
    const steps: PanelSaveStep[] = [];
    if (dto.stagePatch) {
      steps.push(this.cropStageGateway.updateCropStage(dto.cropId, dto.stageId, dto.stagePatch));
    }
    if (dto.temperaturePatch && Object.keys(dto.temperaturePatch).length > 0) {
      steps.push(upsertTemperatureRequirement(this.cropStageGateway, dto.cropId, dto.stageId, dto.temperaturePatch));
    }
    if (dto.thermalPatch && Object.keys(dto.thermalPatch).length > 0) {
      steps.push(upsertThermalRequirement(this.cropStageGateway, dto.cropId, dto.stageId, dto.thermalPatch));
    }
    return steps;
  }

  private reloadCrop(cropId: number): Observable<Crop> {
    return this.cropGateway.show(cropId);
  }
}
