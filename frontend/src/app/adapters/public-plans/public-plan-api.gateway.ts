import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';
import {
  PublicPlanGateway,
  CreatePublicPlanResponse
} from '../../usecase/public-plans/public-plan-gateway';

@Injectable()
export class PublicPlanApiGateway implements PublicPlanGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  getFarms(region?: string): Observable<Farm[]> {
    const params = region ? { region } : undefined;
    return this.apiClient.get<Farm[]>('/api/v1/public_plans/farms', { params });
  }

  getFarmSizes(): Observable<FarmSizeOption[]> {
    return this.apiClient.get<FarmSizeOption[]>(
      '/api/v1/public_plans/farm_sizes'
    );
  }

  getCrops(farmId: number): Observable<Crop[]> {
    return this.apiClient.get<Crop[]>('/api/v1/public_plans/crops', {
      params: { farm_id: farmId.toString() }
    });
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
}
