import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import {
  PublicPlanGateway,
  CreatePublicPlanResponse,
  SavePublicPlanResponse
} from '../../usecase/public-plans/public-plan-gateway';
import { PUBLIC_PLAN_SESSION_PORT, PublicPlanSessionPort } from '../../usecase/public-plans/public-plan-session.port';
import { Inject } from '@angular/core';
import { publicPlanSessionHeaders } from './public-plan-session-headers';

@Injectable()
export class PublicPlanApiGateway implements PublicPlanGateway {
  constructor(
    private readonly apiClient: ApiService,
    @Inject(PUBLIC_PLAN_SESSION_PORT) private readonly publicPlanSession: PublicPlanSessionPort
  ) {}

  getFarms(region?: string): Observable<Farm[]> {
    const params = region ? { region } : undefined;
    return this.apiClient.get<Farm[]>('/api/v1/public_plans/farms', { params });
  }

  getCrops(farmId: number): Observable<Crop[]> {
    const params = { farm_id: farmId.toString() };
    return this.apiClient.get<Crop[]>('/api/v1/public_plans/crops', { params });
  }

  createPlan(
    farmId: number,
    farmSizeId: string,
    cropIds: number[]
  ): Observable<CreatePublicPlanResponse> {
    const requestBody = { farm_id: farmId, farm_size_id: farmSizeId, crop_ids: cropIds };
    return this.apiClient.post<CreatePublicPlanResponse>(
      '/api/v1/public_plans/plans',
      requestBody,
      { headers: publicPlanSessionHeaders(this.publicPlanSession.ensureSessionToken()) }
    );
  }

  savePlan(planId: number): Observable<SavePublicPlanResponse> {
    return this.apiClient.post<SavePublicPlanResponse>(
      '/api/v1/public_plans/save_plan',
      { plan_id: planId }
    );
  }
}
