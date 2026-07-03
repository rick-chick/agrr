import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';
import { delay } from 'rxjs/operators';
import {
  GanttAddCropRequest,
  GanttAddFieldRequest
} from '../../usecase/plans/gantt-plan-mutation.dtos';
import {
  GanttPlanMutationCommandResult,
  ganttMutationCommandFailure,
  ganttMutationCommandSuccess
} from '../../domain/plans/gantt-plan-mutation';
import { CultivationPlanData, CultivationData } from '../../domain/plans/cultivation-plan-data';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { buildLandingDemoPlanFixture } from '../../domain/plans/landing-demo-plan.fixture';
import { buildLandingDemoClimateForCultivation } from '../../domain/plans/landing-demo-climate.fixture';
import {
  LandingDemoLabels,
  LANDING_DEMO_LABELS_FIXTURE
} from '../../domain/plans/landing-demo-i18n.keys';
import { LANDING_DEMO_PLAN_ID } from '../../domain/plans/cultivation-plan-context-type';
import {
  applyGanttCultivationMove,
  buildGanttFieldGroups,
  formatIsoDateOnly
} from '../../domain/plans/gantt-chart-layout';

const DEMO_MUTATION_DELAY_MS = 350;
const DEFAULT_ADD_CROP_DAYS = 90;

function clonePlan(data: CultivationPlanData): CultivationPlanData {
  return structuredClone(data);
}

@Injectable({ providedIn: 'root' })
export class DemoGanttPlanMemoryGateway {
  private labels: LandingDemoLabels = LANDING_DEMO_LABELS_FIXTURE;
  private state: CultivationPlanData = clonePlan(buildLandingDemoPlanFixture(this.labels));
  private nextCultivationId = 2000;
  private nextFieldId = 200;

  initialize(labels: LandingDemoLabels): void {
    this.labels = labels;
    this.state = clonePlan(buildLandingDemoPlanFixture(labels));
    this.nextCultivationId = 2000;
    this.nextFieldId = 200;
  }

  getSnapshot(): CultivationPlanData {
    return clonePlan(this.state);
  }

  getDemoClimate(fieldCultivationId: number): FieldCultivationClimateData | null {
    const cultivation =
      this.state.data.cultivations.find((c) => c.id === fieldCultivationId) ?? null;
    if (!cultivation) {
      return null;
    }
    return buildLandingDemoClimateForCultivation(cultivation, this.labels);
  }

  loadPlan(_planId: number): Observable<CultivationPlanData> {
    return of(this.getSnapshot());
  }

  adjustCultivationMove(input: {
    planId: number;
    cultivationId: number;
    toFieldId: number;
    newStartDate: Date;
  }): Observable<GanttPlanMutationCommandResult> {
    if (input.planId !== LANDING_DEMO_PLAN_ID) {
      return of(ganttMutationCommandFailure());
    }
    const data = clonePlan(this.state);
    const cultivation = data.data.cultivations.find((c) => c.id === input.cultivationId);
    if (!cultivation) {
      return of(ganttMutationCommandFailure('cultivation not found'));
    }
    const fieldGroups = buildGanttFieldGroups(data.data.fields, data.data.cultivations);
    const targetIndex = fieldGroups.findIndex((g) => g.fieldId === input.toFieldId);
    if (targetIndex < 0) {
      return of(ganttMutationCommandFailure('field not found'));
    }
    const target = fieldGroups[targetIndex]!;
    applyGanttCultivationMove({
      cultivation,
      fieldGroups,
      newFieldName: target.fieldName,
      newFieldIndex: targetIndex,
      newStartDate: input.newStartDate
    });
    this.state = data;
    return of(ganttMutationCommandSuccess()).pipe(delay(DEMO_MUTATION_DELAY_MS));
  }

  addCrop(planId: number, payload: GanttAddCropRequest): Observable<GanttPlanMutationCommandResult> {
    if (planId !== LANDING_DEMO_PLAN_ID) {
      return of(ganttMutationCommandFailure());
    }
    const data = clonePlan(this.state);
    const crop =
      data.data.available_crops?.find((c) => c.id === payload.crop_id) ??
      data.data.crops.find((c) => c.id === payload.crop_id);
    if (!crop) {
      return of(ganttMutationCommandFailure('crop not found'));
    }
    const field = data.data.fields[0];
    if (!field) {
      return of(ganttMutationCommandFailure('no field'));
    }
    const startIso = payload.display_start_date ?? data.data.planning_start_date;
    const start = new Date(startIso);
    const end = new Date(start);
    end.setDate(end.getDate() + DEFAULT_ADD_CROP_DAYS);
    const newId = this.nextCultivationId++;
    const newCultivation: CultivationData = {
      id: newId,
      field_id: field.id,
      field_name: field.name,
      crop_id: crop.id,
      crop_name: crop.name,
      area: crop.area_per_unit ?? 1,
      start_date: formatIsoDateOnly(start)!,
      completion_date: formatIsoDateOnly(end)!,
      cultivation_days: DEFAULT_ADD_CROP_DAYS,
      estimated_cost: 0,
      revenue: 0,
      profit: 0,
      status: 'completed'
    };
    data.data.cultivations = [...data.data.cultivations, newCultivation];
    this.state = data;
    return of(ganttMutationCommandSuccess()).pipe(delay(DEMO_MUTATION_DELAY_MS));
  }

  removeCultivation(planId: number, cultivationId: number): Observable<GanttPlanMutationCommandResult> {
    if (planId !== LANDING_DEMO_PLAN_ID) {
      return of(ganttMutationCommandFailure());
    }
    const data = clonePlan(this.state);
    data.data.cultivations = data.data.cultivations.filter((c) => c.id !== cultivationId);
    this.state = data;
    return of(ganttMutationCommandSuccess()).pipe(delay(DEMO_MUTATION_DELAY_MS));
  }

  addField(planId: number, payload: GanttAddFieldRequest): Observable<GanttPlanMutationCommandResult> {
    if (planId !== LANDING_DEMO_PLAN_ID) {
      return of(ganttMutationCommandFailure());
    }
    const data = clonePlan(this.state);
    const id = this.nextFieldId++;
    data.data.fields = [
      ...data.data.fields,
      {
        id,
        field_id: id,
        name: payload.field_name,
        area: payload.field_area,
        daily_fixed_cost: payload.daily_fixed_cost ?? 0
      }
    ];
    this.state = data;
    return of(ganttMutationCommandSuccess()).pipe(delay(DEMO_MUTATION_DELAY_MS));
  }

  removeField(planId: number, fieldId: number): Observable<GanttPlanMutationCommandResult> {
    if (planId !== LANDING_DEMO_PLAN_ID) {
      return of(ganttMutationCommandFailure());
    }
    const data = clonePlan(this.state);
    data.data.fields = data.data.fields.filter((f) => f.id !== fieldId);
    data.data.cultivations = data.data.cultivations.filter((c) => c.field_id !== fieldId);
    this.state = data;
    return of(ganttMutationCommandSuccess()).pipe(delay(DEMO_MUTATION_DELAY_MS));
  }
}
