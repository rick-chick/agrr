import { Injectable } from '@angular/core';
import { Observable, of, throwError } from 'rxjs';
import { delay } from 'rxjs/operators';
import { ApiService } from '../../services/api.service';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { FieldClimateGateway } from '../../usecase/plans/field-climate/field-climate.gateway';
import { FetchFieldClimateDataRequestDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { DemoGanttPlanStore } from '../../services/plans/demo-gantt-plan-store.service';

@Injectable()
export class FieldClimateApiGateway implements FieldClimateGateway {
  constructor(
    private readonly apiClient: ApiService,
    private readonly demoPlanStore: DemoGanttPlanStore
  ) {}

  fetchFieldClimateData(
    dto: FetchFieldClimateDataRequestDto
  ): Observable<FieldCultivationClimateData> {
    if (dto.planType === 'demo') {
      const climate = this.demoPlanStore.getDemoClimate(dto.fieldCultivationId);
      if (!climate) {
        return throwError(() => new Error('demo climate not found'));
      }
      return of(climate).pipe(delay(150));
    }

    const basePath =
      dto.planType === 'public' ? '/api/v1/public_plans' : '/api/v1/plans';

    const url = `${basePath}/field_cultivations/${dto.fieldCultivationId}/climate_data`;

    const params: { [key: string]: string } = {};
    if (dto.displayStartDate) {
      params['display_start_date'] = dto.displayStartDate;
    }
    if (dto.displayEndDate) {
      params['display_end_date'] = dto.displayEndDate;
    }

    return this.apiClient.get<FieldCultivationClimateData>(url, {
      params: Object.keys(params).length > 0 ? params : undefined
    });
  }
}
