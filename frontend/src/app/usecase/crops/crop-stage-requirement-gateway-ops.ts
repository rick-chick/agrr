import { Observable } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import {
  CreateNutrientRequirementPayload,
  CreateSunshineRequirementPayload,
  CreateTemperatureRequirementPayload,
  CreateThermalRequirementPayload,
  CropStageGateway,
  UpdateNutrientRequirementPayload,
  UpdateSunshineRequirementPayload,
  UpdateTemperatureRequirementPayload,
  UpdateThermalRequirementPayload
} from './crop-stage-gateway';
import {
  NutrientRequirement,
  SunshineRequirement,
  TemperatureRequirement,
  ThermalRequirement
} from '../../domain/crops/crop';

function toCreatePayload<T extends object>(payload: T): Partial<{ [K in keyof T]: Exclude<T[K], null> }> {
  const result: Partial<{ [K in keyof T]: Exclude<T[K], null> }> = {};
  for (const key of Object.keys(payload) as (keyof T)[]) {
    const value = payload[key];
    if (value !== null) {
      result[key] = value as Exclude<T[typeof key], null>;
    }
  }
  return result;
}

export function upsertTemperatureRequirement(
  gateway: CropStageGateway,
  cropId: number,
  stageId: number,
  payload: UpdateTemperatureRequirementPayload
): Observable<TemperatureRequirement> {
  return gateway.getTemperatureRequirement(cropId, stageId).pipe(
    switchMap((existing) =>
      existing
        ? gateway.updateTemperatureRequirement(cropId, stageId, payload)
        : gateway.createTemperatureRequirement(
            cropId,
            stageId,
            toCreatePayload(payload) as CreateTemperatureRequirementPayload
          )
    )
  );
}

export function upsertThermalRequirement(
  gateway: CropStageGateway,
  cropId: number,
  stageId: number,
  payload: UpdateThermalRequirementPayload
): Observable<ThermalRequirement> {
  return gateway.getThermalRequirement(cropId, stageId).pipe(
    switchMap((existing) =>
      existing
        ? gateway.updateThermalRequirement(cropId, stageId, payload)
        : gateway.createThermalRequirement(
            cropId,
            stageId,
            toCreatePayload(payload) as CreateThermalRequirementPayload
          )
    )
  );
}

export function upsertSunshineRequirement(
  gateway: CropStageGateway,
  cropId: number,
  stageId: number,
  payload: UpdateSunshineRequirementPayload
): Observable<SunshineRequirement> {
  return gateway.getSunshineRequirement(cropId, stageId).pipe(
    switchMap((existing) =>
      existing
        ? gateway.updateSunshineRequirement(cropId, stageId, payload)
        : gateway.createSunshineRequirement(
            cropId,
            stageId,
            toCreatePayload(payload) as CreateSunshineRequirementPayload
          )
    )
  );
}

export function upsertNutrientRequirement(
  gateway: CropStageGateway,
  cropId: number,
  stageId: number,
  payload: UpdateNutrientRequirementPayload
): Observable<NutrientRequirement> {
  return gateway.getNutrientRequirement(cropId, stageId).pipe(
    switchMap((existing) =>
      existing
        ? gateway.updateNutrientRequirement(cropId, stageId, payload)
        : gateway.createNutrientRequirement(
            cropId,
            stageId,
            toCreatePayload(payload) as CreateNutrientRequirementPayload
          )
    )
  );
}
