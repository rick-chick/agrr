import type { PlanVarianceActionItem, PlanVsActualSummary } from './plan-vs-actual-summary';
import type { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { mapWeatherProposalsToAttentionTriggers } from './map-weather-proposals-to-attention-triggers';
import type { WeatherRescheduleProposal } from './weather-reschedule-proposal';
import type { WeatherRescheduleTriggerType } from './weather-reschedule-proposal';

export interface PlanWorkTodayAttentionField {
  fieldCultivationId: number;
  fieldName: string;
  cropName: string;
}

export interface PlanWorkTodayAttentionTask {
  itemId: number;
  name: string;
}

export interface PlanWorkTodayAttentionWeatherTrigger {
  proposalId: string;
  triggerType: WeatherRescheduleTriggerType;
  fieldName: string;
  cropName: string;
  rationaleI18nKey: string;
  rationaleI18nParams: Record<string, string | number>;
}

export interface PlanWorkTodayAttentionSummary {
  frostRiskCount: number;
  frostRiskFields: PlanWorkTodayAttentionField[];
  gddDelayCount: number;
  gddDelayTasks: PlanWorkTodayAttentionTask[];
  thresholdExceededCount: number;
  thresholdExceededTasks: PlanWorkTodayAttentionTask[];
  weatherTriggers: PlanWorkTodayAttentionWeatherTrigger[];
  hasAnyAttention: boolean;
}

const FROST_SENSITIVE_WEATHER_DEPENDENCIES = new Set(['high']);

function isGddDelayItem(item: PlanVarianceActionItem): boolean {
  return item.exceedance_kind === 'gdd' || item.exceedance_kind === 'both';
}

function toAttentionTask(item: PlanVarianceActionItem): PlanWorkTodayAttentionTask {
  return {
    itemId: item.item_id,
    name: item.name
  };
}

function detectFrostRiskFields(activeRows: WorkDayListRowDto[]): PlanWorkTodayAttentionField[] {
  const byField = new Map<number, PlanWorkTodayAttentionField>();

  for (const row of activeRows) {
    if (row.item.completed) {
      continue;
    }
    if (!FROST_SENSITIVE_WEATHER_DEPENDENCIES.has(row.item.weather_dependency)) {
      continue;
    }
    if (byField.has(row.item.field_cultivation_id)) {
      continue;
    }
    byField.set(row.item.field_cultivation_id, {
      fieldCultivationId: row.item.field_cultivation_id,
      fieldName: row.fieldName,
      cropName: row.cropName
    });
  }

  return [...byField.values()];
}

export function buildPlanWorkTodayAttention(
  summary: PlanVsActualSummary,
  activeRows: WorkDayListRowDto[],
  weatherProposals: WeatherRescheduleProposal[] = []
): PlanWorkTodayAttentionSummary {
  const actionItems = summary.action_required_items ?? [];
  const frostRiskFields = detectFrostRiskFields(activeRows);
  const gddDelayTasks = actionItems.filter(isGddDelayItem).map(toAttentionTask);
  const thresholdExceededTasks = actionItems.map(toAttentionTask);
  const weatherTriggers = mapWeatherProposalsToAttentionTriggers(weatherProposals);

  const frostRiskCount = frostRiskFields.length;
  const gddDelayCount = gddDelayTasks.length;
  const thresholdExceededCount = thresholdExceededTasks.length;

  return {
    frostRiskCount,
    frostRiskFields,
    gddDelayCount,
    gddDelayTasks,
    thresholdExceededCount,
    thresholdExceededTasks,
    weatherTriggers,
    hasAnyAttention:
      frostRiskCount > 0 ||
      gddDelayCount > 0 ||
      thresholdExceededCount > 0 ||
      weatherTriggers.length > 0
  };
}
