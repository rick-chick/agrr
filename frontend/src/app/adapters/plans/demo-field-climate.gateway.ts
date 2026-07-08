import { Injectable } from '@angular/core';
import { Observable, of, throwError } from 'rxjs';
import { delay } from 'rxjs/operators';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { FieldClimateGateway } from '../../usecase/plans/field-climate/field-climate.gateway';
import { FetchFieldClimateDataRequestDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { DemoGanttPlanMemoryGateway } from './demo-gantt-plan-memory.gateway';

@Injectable()
export class DemoFieldClimateGateway implements FieldClimateGateway {
  constructor(private readonly demoPlanStore: DemoGanttPlanMemoryGateway) {}

  fetchFieldClimateData(
    dto: FetchFieldClimateDataRequestDto
  ): Observable<FieldCultivationClimateData> {
    if (dto.planType !== 'demo') {
      return throwError(
        () => new Error('demo plan type is not supported by demo climate gateway')
      );
    }

    const climate = this.demoPlanStore.getDemoClimate(dto.fieldCultivationId);
    if (!climate) {
      return throwError(() => new Error('demo climate not found'));
    }
    return of(climate).pipe(delay(150));
  }
}
