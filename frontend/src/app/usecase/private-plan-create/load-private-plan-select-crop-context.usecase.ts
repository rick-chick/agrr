import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { LoadPrivatePlanSelectCropContextInputPort } from './load-private-plan-select-crop-context.input-port';
import { LoadPrivatePlanSelectCropContextOutputPort, LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT } from './load-private-plan-select-crop-context.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { LoadPrivatePlanSelectCropContextInputDto } from './load-private-plan-select-crop-context.dtos';

@Injectable()
export class LoadPrivatePlanSelectCropContextUseCase implements LoadPrivatePlanSelectCropContextInputPort {
  constructor(
    @Inject(LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT) private readonly outputPort: LoadPrivatePlanSelectCropContextOutputPort,
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY) private readonly gateway: PrivatePlanCreateGateway
  ) {}

  execute(dto: LoadPrivatePlanSelectCropContextInputDto): void {
    forkJoin({
      farmWithTotalArea: this.gateway.fetchFarm(dto.farmId),
      crops: this.gateway.fetchCrops()
    }).subscribe({
      next: (data) => this.outputPort.present({
        farm: data.farmWithTotalArea.farm,
        totalArea: data.farmWithTotalArea.totalArea,
        crops: data.crops
      }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}