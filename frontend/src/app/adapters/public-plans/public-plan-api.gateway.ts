import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';
import {
  PublicPlanGateway,
  CreatePublicPlanResponse,
  SavePublicPlanResponse
} from '../../usecase/public-plans/public-plan-gateway';

@Injectable()
export class PublicPlanApiGateway implements PublicPlanGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  getFarms(region?: string): Observable<Farm[]> {
    const params = region ? { region } : undefined;
    console.log('🌱 [PublicPlanApiGateway] getFarms called with region:', region, 'params:', params);
    const result = this.apiClient.get<Farm[]>('/api/v1/public_plans/farms', { params });
    result.subscribe({
      next: (data) => console.log('🌱 [PublicPlanApiGateway] getFarms response:', data?.length, 'farms'),
      error: (err) => console.log('🌱 [PublicPlanApiGateway] getFarms error:', err)
    });
    return result;
  }

  getFarmSizes(): Observable<FarmSizeOption[]> {
    console.log('🌱 [PublicPlanApiGateway] getFarmSizes called');
    const result = this.apiClient.get<FarmSizeOption[]>(
      '/api/v1/public_plans/farm_sizes'
    );
    result.subscribe({
      next: (data) => console.log('🌱 [PublicPlanApiGateway] getFarmSizes response:', data?.length, 'sizes'),
      error: (err) => console.log('🌱 [PublicPlanApiGateway] getFarmSizes error:', err)
    });
    return result;
  }

  getCrops(farmId: number): Observable<Crop[]> {
    console.log('🌱 [PublicPlanApiGateway] getCrops called with farmId:', farmId);
    const params = { farm_id: farmId.toString() };
    console.log('🌱 [PublicPlanApiGateway] API call params:', params);
    return this.apiClient.get<Crop[]>('/api/v1/public_plans/crops', { params });
  }

  createPlan(
    farmId: number,
    farmSizeId: string,
    cropIds: number[]
  ): Observable<CreatePublicPlanResponse> {
    return this.apiClient.post<CreatePublicPlanResponse>(
      '/api/v1/public_plans/plans',
      { farm_id: farmId, farm_size_id: farmSizeId, crop_ids: cropIds }
    );
  }

  savePlan(planId: number): Observable<SavePublicPlanResponse> {
    return this.apiClient.post<SavePublicPlanResponse>(
      '/api/v1/public_plans/save_plan',
      { plan_id: planId }
    );
  }
}
