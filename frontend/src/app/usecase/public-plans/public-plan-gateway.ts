import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

export interface CreatePublicPlanResponse {
  plan_id: number;
}

export interface SavePublicPlanResponse {
  success: boolean;
  error?: string;
}

export interface PublicPlanGateway {
  getFarms(region?: string): Observable<Farm[]>;
  getFarmSizes(): Observable<FarmSizeOption[]>;
  getCrops(farmId: number): Observable<Crop[]>;
  createPlan(
    farmId: number,
    farmSizeId: string,
    cropIds: number[]
  ): Observable<CreatePublicPlanResponse>;
  savePlan(planId: number): Observable<SavePublicPlanResponse>;
}

export const PUBLIC_PLAN_GATEWAY = new InjectionToken<PublicPlanGateway>(
  'PUBLIC_PLAN_GATEWAY'
);
