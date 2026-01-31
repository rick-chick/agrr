import { Injectable } from '@angular/core';
import { Observable, of, throwError } from 'rxjs';
import { map, catchError, switchMap } from 'rxjs/operators';
import { MastersClientService } from '../../services/masters/masters-client.service';
import {
  CropStage,
  TemperatureRequirement,
  ThermalRequirement,
  SunshineRequirement,
  NutrientRequirement
} from '../../domain/crops/crop';
import { CropStageGateway } from '../../usecase/crops/crop-stage-gateway';

@Injectable()
export class CropStageApiGateway implements CropStageGateway {
  constructor(private readonly client: MastersClientService) {}

  // CropStage CRUD
  createCropStage(cropId: number, payload: { name: string; order: number }): Observable<CropStage> {
    return this.client.post<CropStage>(`/crops/${cropId}/crop_stages`, { crop_stage: payload });
  }

  updateCropStage(cropId: number, stageId: number, payload: { name?: string; order?: number }): Observable<CropStage> {
    return this.client.patch<CropStage>(`/crops/${cropId}/crop_stages/${stageId}`, { crop_stage: payload });
  }

  deleteCropStage(cropId: number, stageId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/crop_stages/${stageId}`);
  }

  // Temperature Requirement
  getTemperatureRequirement(cropId: number, stageId: number): Observable<TemperatureRequirement | null> {
    return this.client.get<TemperatureRequirement>(`/crops/${cropId}/crop_stages/${stageId}/temperature_requirement`).pipe(
      catchError(error => {
        if (error.status === 404) {
          return of(null);
        }
        return throwError(error);
      })
    );
  }

  createTemperatureRequirement(
    cropId: number,
    stageId: number,
    payload: {
      base_temperature?: number;
      optimal_min?: number;
      optimal_max?: number;
      low_stress_threshold?: number;
      high_stress_threshold?: number;
      frost_threshold?: number;
      sterility_risk_threshold?: number;
      max_temperature?: number;
    }
  ): Observable<TemperatureRequirement> {
    return this.client.post<TemperatureRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/temperature_requirement`,
      { temperature_requirement: payload }
    );
  }

  updateTemperatureRequirement(
    cropId: number,
    stageId: number,
    payload: {
      base_temperature?: number;
      optimal_min?: number;
      optimal_max?: number;
      low_stress_threshold?: number;
      high_stress_threshold?: number;
      frost_threshold?: number;
      sterility_risk_threshold?: number;
      max_temperature?: number;
    }
  ): Observable<TemperatureRequirement> {
    return this.client.patch<TemperatureRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/temperature_requirement`,
      { temperature_requirement: payload }
    );
  }

  deleteTemperatureRequirement(cropId: number, stageId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/crop_stages/${stageId}/temperature_requirement`);
  }

  // Thermal Requirement
  getThermalRequirement(cropId: number, stageId: number): Observable<ThermalRequirement | null> {
    return this.client.get<ThermalRequirement>(`/crops/${cropId}/crop_stages/${stageId}/thermal_requirement`).pipe(
      catchError(error => {
        if (error.status === 404) {
          return of(null);
        }
        return throwError(error);
      })
    );
  }

  createThermalRequirement(
    cropId: number,
    stageId: number,
    payload: { required_gdd?: number }
  ): Observable<ThermalRequirement> {
    return this.client.post<ThermalRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/thermal_requirement`,
      { thermal_requirement: payload }
    );
  }

  updateThermalRequirement(
    cropId: number,
    stageId: number,
    payload: { required_gdd?: number }
  ): Observable<ThermalRequirement> {
    return this.client.patch<ThermalRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/thermal_requirement`,
      { thermal_requirement: payload }
    );
  }

  deleteThermalRequirement(cropId: number, stageId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/crop_stages/${stageId}/thermal_requirement`);
  }

  // Sunshine Requirement
  getSunshineRequirement(cropId: number, stageId: number): Observable<SunshineRequirement | null> {
    return this.client.get<SunshineRequirement>(`/crops/${cropId}/crop_stages/${stageId}/sunshine_requirement`).pipe(
      catchError(error => {
        if (error.status === 404) {
          return of(null);
        }
        return throwError(error);
      })
    );
  }

  createSunshineRequirement(
    cropId: number,
    stageId: number,
    payload: { minimum_sunshine_hours?: number; target_sunshine_hours?: number }
  ): Observable<SunshineRequirement> {
    return this.client.post<SunshineRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/sunshine_requirement`,
      { sunshine_requirement: payload }
    );
  }

  updateSunshineRequirement(
    cropId: number,
    stageId: number,
    payload: { minimum_sunshine_hours?: number; target_sunshine_hours?: number }
  ): Observable<SunshineRequirement> {
    return this.client.patch<SunshineRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/sunshine_requirement`,
      { sunshine_requirement: payload }
    );
  }

  deleteSunshineRequirement(cropId: number, stageId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/crop_stages/${stageId}/sunshine_requirement`);
  }

  // Nutrient Requirement
  getNutrientRequirement(cropId: number, stageId: number): Observable<NutrientRequirement | null> {
    return this.client.get<NutrientRequirement>(`/crops/${cropId}/crop_stages/${stageId}/nutrient_requirement`).pipe(
      catchError(error => {
        if (error.status === 404) {
          return of(null);
        }
        return throwError(error);
      })
    );
  }

  createNutrientRequirement(
    cropId: number,
    stageId: number,
    payload: { daily_uptake_n?: number; daily_uptake_p?: number; daily_uptake_k?: number; region?: string }
  ): Observable<NutrientRequirement> {
    return this.client.post<NutrientRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/nutrient_requirement`,
      { nutrient_requirement: payload }
    );
  }

  updateNutrientRequirement(
    cropId: number,
    stageId: number,
    payload: { daily_uptake_n?: number; daily_uptake_p?: number; daily_uptake_k?: number; region?: string }
  ): Observable<NutrientRequirement> {
    return this.client.patch<NutrientRequirement>(
      `/crops/${cropId}/crop_stages/${stageId}/nutrient_requirement`,
      { nutrient_requirement: payload }
    );
  }

  deleteNutrientRequirement(cropId: number, stageId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/crop_stages/${stageId}/nutrient_requirement`);
  }
}