import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from './create-private-plan.dtos';

export interface FarmWithTotalAreaDto {
  farm: Farm;
  totalArea: number;
}

export interface PrivatePlanCreateGateway {
  fetchFarms(): Observable<Farm[]>;
  fetchFarm(farmId: number): Observable<FarmWithTotalAreaDto>;
  fetchCrops(): Observable<Crop[]>;
  createPlan(dto: CreatePrivatePlanInputDto): Observable<CreatePrivatePlanResponseDto>;
}

export const PRIVATE_PLAN_CREATE_GATEWAY = new InjectionToken<PrivatePlanCreateGateway>(
  'PRIVATE_PLAN_CREATE_GATEWAY'
);