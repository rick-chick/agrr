import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { countPlanFrostRisks } from '../../domain/plans/detect-field-frost-risk-for-date';
import { FIELD_CLIMATE_GATEWAY, FieldClimateGateway } from './field-climate/field-climate.gateway';
import { LoadPlanWorkFrostRiskInputDto } from './load-plan-work-frost-risk.dtos';
import { LoadPlanWorkFrostRiskInputPort } from './load-plan-work-frost-risk.input-port';
import {
  LOAD_PLAN_WORK_FROST_RISK_OUTPUT_PORT,
  LoadPlanWorkFrostRiskOutputPort
} from './load-plan-work-frost-risk.output-port';

@Injectable()
export class LoadPlanWorkFrostRiskUseCase implements LoadPlanWorkFrostRiskInputPort {
  constructor(
    @Inject(LOAD_PLAN_WORK_FROST_RISK_OUTPUT_PORT)
    private readonly outputPort: LoadPlanWorkFrostRiskOutputPort,
    @Inject(FIELD_CLIMATE_GATEWAY) private readonly fieldClimateGateway: FieldClimateGateway
  ) {}

  execute(dto: LoadPlanWorkFrostRiskInputDto): void {
    const uniqueIds = [...new Set(dto.fieldCultivationIds)];
    if (uniqueIds.length === 0) {
      this.outputPort.present({ frostRiskCount: 0, loadGeneration: dto.loadGeneration });
      return;
    }

    forkJoin(
      uniqueIds.map((fieldCultivationId) =>
        this.fieldClimateGateway
          .fetchFieldClimateData({
            planType: 'private',
            fieldCultivationId,
            displayStartDate: dto.today,
            displayEndDate: dto.today
          })
          .pipe(catchError(() => of(null)))
      )
    ).subscribe({
      next: (climates) => {
        const valid = climates.filter((climate): climate is NonNullable<typeof climate> => climate != null);
        this.outputPort.present({
          frostRiskCount: countPlanFrostRisks(valid, dto.today),
          loadGeneration: dto.loadGeneration
        });
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
