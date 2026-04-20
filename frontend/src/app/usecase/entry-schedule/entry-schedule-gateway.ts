import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import {
  EntryScheduleCropsListResponse,
  EntryScheduleCropShowResponse
} from '../../domain/entry-schedule/entry-schedule';

export interface EntryScheduleListQueryOptions {
  predictionEndDate?: string;
  locale?: string;
  /** 1..50、既定はサーバー側 20 */
  limit?: number;
  /** 前レスポンスの meta.next_cursor */
  cursor?: string | null;
}

export interface EntryScheduleGateway {
  getEntryScheduleFarms(region?: string): Observable<Farm[]>;
  getEntryScheduleCrops(
    farmId: number,
    options?: EntryScheduleListQueryOptions
  ): Observable<EntryScheduleCropsListResponse>;
  getEntryScheduleCrop(
    farmId: number,
    cropId: number,
    options?: { predictionEndDate?: string; locale?: string }
  ): Observable<EntryScheduleCropShowResponse>;
}

export const ENTRY_SCHEDULE_GATEWAY = new InjectionToken<EntryScheduleGateway>(
  'ENTRY_SCHEDULE_GATEWAY'
);
