import { Injectable, inject } from '@angular/core';
import { HttpHeaders } from '@angular/common/http';
import { TranslateService } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
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
  private readonly translate = inject(TranslateService);

  constructor(private readonly apiClient: ApiService) {}

  getEntryScheduleFarms(region?: string): Observable<Farm[]> {
    const params = region ? { region } : undefined;
    return this.apiClient.get<Farm[]>('/api/v1/public_plans/entry_schedule/farms', {
      params,
      headers: this.localeHeaders()
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
      { params, headers: this.localeHeaders(options?.locale) }
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
      { params, headers: this.localeHeaders(options?.locale) }
    );
  }

  private localeHeaders(locale?: string): HttpHeaders {
    const lang = locale || this.translate.currentLang || this.translate.defaultLang || 'ja';
    return new HttpHeaders({ 'Accept-Language': lang });
  }
}
