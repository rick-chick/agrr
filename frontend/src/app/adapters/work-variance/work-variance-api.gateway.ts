import { Injectable } from '@angular/core';
import { map, Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { WorkVarianceGateway } from '../../usecase/work-variance/work-variance-gateway';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';

interface VariancePortfolioApiRow {
  farm_id: number;
  farm_name: string;
  plan_id: number;
  plan_year: number | null;
  status: string;
  unrecorded_count: number;
  gdd_delay_count: number;
  threshold_exceeded_count: number;
  days_threshold_exceeded_count: number;
  carryover_not_imported: boolean;
  weather_trigger_count: number;
}

@Injectable()
export class WorkVarianceApiGateway implements WorkVarianceGateway {
  constructor(private readonly apiClient: ApiService) {}

  listVariancePortfolio(): Observable<VariancePortfolioRow[]> {
    return this.apiClient.get<VariancePortfolioApiRow[]>('/api/v1/work/variance_portfolio').pipe(
      map((rows) =>
        rows.map((row) => ({
          farmId: row.farm_id,
          farmName: row.farm_name,
          planId: row.plan_id,
          planYear: row.plan_year,
          status: row.status,
          unrecordedCount: row.unrecorded_count,
          gddDelayCount: row.gdd_delay_count,
          thresholdExceededCount: row.threshold_exceeded_count,
          daysThresholdExceededCount: row.days_threshold_exceeded_count,
          carryoverNotImported: row.carryover_not_imported,
          weatherTriggerCount: row.weather_trigger_count
        }))
      )
    );
  }
}
