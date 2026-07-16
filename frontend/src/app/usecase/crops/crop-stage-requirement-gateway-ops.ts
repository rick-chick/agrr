import { Observable } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import {
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
        : gateway.createTemperatureRequirement(cropId, stageId, payload)
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
        : gateway.createThermalRequirement(cropId, stageId, payload)
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
        : gateway.createSunshineRequirement(cropId, stageId, payload)
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
        : gateway.createNutrientRequirement(cropId, stageId, payload)
    )
  );
}
