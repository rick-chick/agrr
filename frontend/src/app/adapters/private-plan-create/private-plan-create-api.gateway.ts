import { Injectable } from '@angular/core';
import { Observable, forkJoin, map, of, switchMap } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import {
  FarmPlanCreateOption,
  PrivatePlanCreateGateway,
  FarmWithTotalAreaDto
} from '../../usecase/private-plan-create/private-plan-create-gateway';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';

interface FarmWithFields extends Farm {
  fields?: Array<{ area: number | null }>;
}

function countValidFields(fields: Array<{ area: number | null }> | undefined): { count: number; totalArea: number } {
  const valid = (fields ?? []).filter((field) => (field.area ?? 0) > 0);
  return {
    count: valid.length,
    totalArea: valid.reduce((sum, field) => sum + (field.area ?? 0), 0)
  };
}

@Injectable()
export class PrivatePlanCreateApiGateway implements PrivatePlanCreateGateway {
  constructor(private readonly apiClient: ApiService) {}

  fetchFarms(): Observable<Farm[]> {
    return this.apiClient.get<Farm[]>('/api/v1/masters/farms');
  }

  fetchFarmsForPlanCreate(): Observable<FarmPlanCreateOption[]> {
    return this.fetchFarms().pipe(
      switchMap((farms) => {
        if (farms.length === 0) {
          return of([]);
        }
        return forkJoin(
          farms.map((farm) =>
            this.apiClient.get<FarmWithFields>(`/api/v1/masters/farms/${farm.id}`).pipe(
              map((detail) => {
                const { count, totalArea } = countValidFields(detail.fields);
                return {
                  id: farm.id,
                  name: farm.name,
                  fieldCount: count,
                  totalArea,
                  hasValidFields: count > 0
                };
              })
            )
          )
        );
      })
    );
  }

  fetchFarm(farmId: number): Observable<FarmWithTotalAreaDto> {
    return this.apiClient.get<FarmWithFields>(`/api/v1/masters/farms/${farmId}`).pipe(
      map((farm) => {
        const totalArea = farm.fields?.reduce((sum, field) => sum + (field.area || 0), 0) || 0;
        const { fields: _fields, ...farmWithoutFields } = farm;
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
        plan_name: dto.planName
      }
    };
    return this.apiClient.post<CreatePrivatePlanResponseDto>('/api/v1/plans', requestBody);
  }
}