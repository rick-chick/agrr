import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { Farm } from '../../domain/farms/farm';
import {
  EntryScheduleCropsListResponse,
  EntryScheduleCropShowResponse
} from '../../domain/entry-schedule/entry-schedule';
import {
  EntryScheduleGateway,
  EntryScheduleListQueryOptions
} from '../../usecase/entry-schedule/entry-schedule-gateway';

@Injectable({ providedIn: 'root' })
export class EntryScheduleApiGateway implements EntryScheduleGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  getEntryScheduleFarms(region?: string): Observable<Farm[]> {
    const params = region ? { region } : undefined;
    return this.apiClient.get<Farm[]>('/api/v1/public_plans/entry_schedule/farms', {
      params
    });
  }

  getEntryScheduleCrops(
    farmId: number,
    options?: EntryScheduleListQueryOptions
  ): Observable<EntryScheduleCropsListResponse> {
    const params: Record<string, string> = { farm_id: farmId.toString() };
    if (options?.predictionEndDate) {
      params['prediction_end_date'] = options.predictionEndDate;
    }
    if (options?.locale) {
      params['locale'] = options.locale;
    }
    if (options?.limit != null) {
      params['limit'] = String(options.limit);
    }
    if (options?.cursor) {
      params['cursor'] = options.cursor;
    }
    return this.apiClient.get<EntryScheduleCropsListResponse>(
      '/api/v1/public_plans/entry_schedule/crops',
      { params }
    );
  }

  getEntryScheduleCrop(
    farmId: number,
    cropId: number,
    options?: { predictionEndDate?: string; locale?: string }
  ): Observable<EntryScheduleCropShowResponse> {
    const params: Record<string, string> = { farm_id: farmId.toString() };
    if (options?.predictionEndDate) {
      params['prediction_end_date'] = options.predictionEndDate;
    }
    if (options?.locale) {
      params['locale'] = options.locale;
    }
    return this.apiClient.get<EntryScheduleCropShowResponse>(
      `/api/v1/public_plans/entry_schedule/crops/${cropId}`,
      { params }
    );
  }
}
