import { Inject, Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { LoadPublicPlanCropsInputDto } from './load-public-plan-crops.dtos';
import { LoadPublicPlanCropsInputPort } from './load-public-plan-crops.input-port';
import {
  LoadPublicPlanCropsOutputPort,
  LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT
} from './load-public-plan-crops.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';

@Injectable()
export class LoadPublicPlanCropsUseCase implements LoadPublicPlanCropsInputPort {
  constructor(
    @Inject(LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT)
    private readonly outputPort: LoadPublicPlanCropsOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway,
    private readonly translate: TranslateService
  ) {}

  execute(dto: LoadPublicPlanCropsInputDto): void {
    console.log('🌱 [LoadPublicPlanCropsUseCase] execute called with farmId:', dto.farmId);
    if (!dto.farmId || dto.farmId <= 0) {
      console.error('🌱 [LoadPublicPlanCropsUseCase] invalid farmId:', dto.farmId);
      this.outputPort.onError({ message: this.translate.instant('public_plans.invalid_farm_id') });
      return;
    }
    this.publicPlanGateway.getCrops(dto.farmId).subscribe({
      next: (crops) => {
        console.log('🌱 [LoadPublicPlanCropsUseCase] received crops:', crops);
        this.outputPort.present({ crops });
      },
      error: (err: Error) => {
        console.error('🌱 [LoadPublicPlanCropsUseCase] error:', err);
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' });
      }
    });
  }
}
