import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { CropStage, TemperatureRequirement, ThermalRequirement, SunshineRequirement, NutrientRequirement } from '../../domain/crops/crop';

export interface CreateCropStagePayload {
  name: string;
  order: number;
}

export interface UpdateCropStagePayload {
  name?: string;
  order?: number;
}

export interface CreateTemperatureRequirementPayload {
  base_temperature?: number;
  optimal_min?: number;
  optimal_max?: number;
  low_stress_threshold?: number;
  high_stress_threshold?: number;
  frost_threshold?: number;
  sterility_risk_threshold?: number;
  max_temperature?: number;
}

export interface UpdateTemperatureRequirementPayload {
  base_temperature?: number;
  optimal_min?: number;
  optimal_max?: number;
  low_stress_threshold?: number;
  high_stress_threshold?: number;
  frost_threshold?: number;
  sterility_risk_threshold?: number;
  max_temperature?: number;
}

export interface CreateThermalRequirementPayload {
  required_gdd?: number;
}

export interface UpdateThermalRequirementPayload {
  required_gdd?: number;
}

export interface CreateSunshineRequirementPayload {
  minimum_sunshine_hours?: number;
  target_sunshine_hours?: number;
}

export interface UpdateSunshineRequirementPayload {
  minimum_sunshine_hours?: number;
  target_sunshine_hours?: number;
}

export interface CreateNutrientRequirementPayload {
  daily_uptake_n?: number;
  daily_uptake_p?: number;
  daily_uptake_k?: number;
  region?: string;
}

export interface UpdateNutrientRequirementPayload {
  daily_uptake_n?: number;
  daily_uptake_p?: number;
  daily_uptake_k?: number;
  region?: string;
}

export interface CropStageGateway {
  // CropStage CRUD
  createCropStage(cropId: number, payload: CreateCropStagePayload): Observable<CropStage>;
  updateCropStage(cropId: number, stageId: number, payload: UpdateCropStagePayload): Observable<CropStage>;
  deleteCropStage(cropId: number, stageId: number): Observable<void>;

  // Temperature Requirement
  getTemperatureRequirement(cropId: number, stageId: number): Observable<TemperatureRequirement | null>;
  createTemperatureRequirement(cropId: number, stageId: number, payload: CreateTemperatureRequirementPayload): Observable<TemperatureRequirement>;
  updateTemperatureRequirement(cropId: number, stageId: number, payload: UpdateTemperatureRequirementPayload): Observable<TemperatureRequirement>;
  deleteTemperatureRequirement(cropId: number, stageId: number): Observable<void>;

  // Thermal Requirement
  getThermalRequirement(cropId: number, stageId: number): Observable<ThermalRequirement | null>;
  createThermalRequirement(cropId: number, stageId: number, payload: CreateThermalRequirementPayload): Observable<ThermalRequirement>;
  updateThermalRequirement(cropId: number, stageId: number, payload: UpdateThermalRequirementPayload): Observable<ThermalRequirement>;
  deleteThermalRequirement(cropId: number, stageId: number): Observable<void>;

  // Sunshine Requirement
  getSunshineRequirement(cropId: number, stageId: number): Observable<SunshineRequirement | null>;
  createSunshineRequirement(cropId: number, stageId: number, payload: CreateSunshineRequirementPayload): Observable<SunshineRequirement>;
  updateSunshineRequirement(cropId: number, stageId: number, payload: UpdateSunshineRequirementPayload): Observable<SunshineRequirement>;
  deleteSunshineRequirement(cropId: number, stageId: number): Observable<void>;

  // Nutrient Requirement
  getNutrientRequirement(cropId: number, stageId: number): Observable<NutrientRequirement | null>;
  createNutrientRequirement(cropId: number, stageId: number, payload: CreateNutrientRequirementPayload): Observable<NutrientRequirement>;
  updateNutrientRequirement(cropId: number, stageId: number, payload: UpdateNutrientRequirementPayload): Observable<NutrientRequirement>;
  deleteNutrientRequirement(cropId: number, stageId: number): Observable<void>;
}

export const CROP_STAGE_GATEWAY = new InjectionToken<CropStageGateway>('CROP_STAGE_GATEWAY');