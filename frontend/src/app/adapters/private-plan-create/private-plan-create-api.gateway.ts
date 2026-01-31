import { Injectable } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { PrivatePlanCreateGateway, FarmWithTotalAreaDto } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';

interface FarmWithFields extends Farm {
  fields?: Array<{ area: number | null }>;
}

@Injectable()
export class PrivatePlanCreateApiGateway implements PrivatePlanCreateGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  fetchFarms(): Observable<Farm[]> {
    return this.apiClient.get<Farm[]>('/api/v1/masters/farms');
  }

  fetchFarm(farmId: number): Observable<FarmWithTotalAreaDto> {
    return this.apiClient.get<FarmWithFields>(`/api/v1/masters/farms/${farmId}`).pipe(
      map((farm) => {
        const totalArea = farm.fields?.reduce((sum, field) => sum + (field.area || 0), 0) || 0;
        const { fields, ...farmWithoutFields } = farm;
        return {
          farm: farmWithoutFields as Farm,
          totalArea
        };
      })
    );
  }

  fetchCrops(): Observable<Crop[]> {
    return this.apiClient.get<Crop[]>('/api/v1/masters/crops');
  }

  createPlan(dto: CreatePrivatePlanInputDto): Observable<CreatePrivatePlanResponseDto> {
    const requestBody = {
      plan: {
        farm_id: dto.farmId,
        plan_name: dto.planName,
        crop_ids: dto.cropIds
      }
    };
    return this.apiClient.post<CreatePrivatePlanResponseDto>('/api/v1/plans', requestBody);
  }
}