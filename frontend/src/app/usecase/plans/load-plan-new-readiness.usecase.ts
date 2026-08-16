import { Inject, Injectable } from '@angular/core';
import { catchError, forkJoin, map, Observable, of, switchMap } from 'rxjs';
import { buildPlanCreateReadiness, PlanCreateReadiness } from '../../domain/plans/plan-create-readiness';
import { CROP_GATEWAY, CropGateway } from '../crops/crop-gateway';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from '../crops/crop-task-schedule-blueprint-gateway';
import {
  PRIVATE_PLAN_CREATE_GATEWAY,
  PrivatePlanCreateGateway
} from '../private-plan-create/private-plan-create-gateway';

@Injectable()
export class LoadPlanNewReadinessUseCase {
  constructor(
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY)
    private readonly planCreateGateway: PrivatePlanCreateGateway,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly blueprintGateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(farmId: number, fieldCount: number, hasValidFields: boolean): Observable<PlanCreateReadiness> {
    return forkJoin({
      farm: this.planCreateGateway.fetchFarm(farmId).pipe(catchError(() => of(null))),
      crops: this.planCreateGateway.fetchCrops().pipe(catchError(() => of([])))
    }).pipe(
      switchMap(({ farm, crops }) => {
        const userCrops = crops.filter((crop) => !crop.is_reference);
        if (userCrops.length === 0) {
          return of(
            buildPlanCreateReadiness({
              farmId,
              fieldCount,
              hasValidFields,
              weatherStatus: farm?.farm.weather_data_status,
              crops: [],
              cropBlueprints: {}
            })
          );
        }

        return forkJoin(
          userCrops.map((crop) =>
            forkJoin({
              detail: this.cropGateway.show(crop.id).pipe(catchError(() => of(crop))),
              blueprints: this.blueprintGateway.list(crop.id).pipe(catchError(() => of([])))
            }).pipe(
              map(({ detail, blueprints }) => ({
                crop: detail,
                blueprints
              }))
            )
          )
        ).pipe(
          map((results) => {
            const cropBlueprints: Record<number, typeof results[0]['blueprints']> = {};
            const detailedCrops = results.map(({ crop, blueprints }) => {
              cropBlueprints[crop.id] = blueprints;
              return crop;
            });
            return buildPlanCreateReadiness({
              farmId,
              fieldCount,
              hasValidFields,
              weatherStatus: farm?.farm.weather_data_status,
              crops: detailedCrops,
              cropBlueprints
            });
          })
        );
      })
    );
  }
}
