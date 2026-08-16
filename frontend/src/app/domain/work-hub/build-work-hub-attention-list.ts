import { resolveVarianceActionItemLinkTarget } from '../plans/resolve-variance-action-item-link-target';
import type { PlanVarianceActionItem } from '../plans/plan-vs-actual-summary';
import type { VarianceActionLinkTarget } from '../plans/resolve-variance-action-item-link-target';
import type { WeatherRescheduleTriggerType } from '../plans/weather-reschedule-proposal';

export interface HubFarmAttentionSource {
  farmId: number;
  farmName: string;
  planId: number;
  actionItems: ReadonlyArray<PlanVarianceActionItem>;
}

export interface HubFarmWeatherTriggerSource {
  farmId: number;
  farmName: string;
  planId: number;
  count: number;
  triggerTypes: ReadonlyArray<WeatherRescheduleTriggerType>;
}

interface WorkHubAttentionItemBase {
  farmId: number;
  farmName: string;
  planId: number;
  itemId: number;
  linkTarget: VarianceActionLinkTarget | 'work';
}

export interface WorkHubVarianceAttentionItem extends WorkHubAttentionItemBase {
  kind: 'variance';
  taskName: string;
  linkTarget: VarianceActionLinkTarget;
}

export interface WorkHubWeatherTriggerAttentionItem extends WorkHubAttentionItemBase {
  kind: 'weather_trigger';
  weatherTriggerCount: number;
  weatherTriggerTypes: ReadonlyArray<WeatherRescheduleTriggerType>;
  linkTarget: 'work';
}

export type WorkHubAttentionItem =
  | WorkHubVarianceAttentionItem
  | WorkHubWeatherTriggerAttentionItem;

export interface WorkHubAttentionList {
  items: WorkHubAttentionItem[];
}

const DEFAULT_ATTENTION_LIMIT = 5;

function attentionPriority(item: PlanVarianceActionItem): number {
  return Math.abs(item.delta_days ?? 0) * 1000 + Math.abs(item.gdd_delta ?? 0);
}

function weatherTriggerItemId(planId: number): number {
  return -planId;
}

export function buildWorkHubAttentionList(
  sources: ReadonlyArray<HubFarmAttentionSource>,
  weatherSources: ReadonlyArray<HubFarmWeatherTriggerSource> = [],
  limit = DEFAULT_ATTENTION_LIMIT
): WorkHubAttentionList {
  const candidates: Array<WorkHubAttentionItem & { priority: number }> = [];

  for (const source of sources) {
    for (const item of source.actionItems) {
      candidates.push({
        kind: 'variance',
        farmId: source.farmId,
        farmName: source.farmName,
        planId: source.planId,
        itemId: item.item_id,
        taskName: item.name,
        linkTarget: resolveVarianceActionItemLinkTarget(item),
        priority: attentionPriority(item)
      });
    }
  }

  for (const source of weatherSources) {
    if (source.count <= 0) {
      continue;
    }
    candidates.push({
      kind: 'weather_trigger',
      farmId: source.farmId,
      farmName: source.farmName,
      planId: source.planId,
      itemId: weatherTriggerItemId(source.planId),
      weatherTriggerCount: source.count,
      weatherTriggerTypes: [...source.triggerTypes],
      linkTarget: 'work',
      priority: source.count * 1000
    });
  }

  const sorted = [...candidates].sort((left, right) => {
    const priorityDiff = right.priority - left.priority;
    if (priorityDiff !== 0) {
      return priorityDiff;
    }
    const farmDiff = left.farmId - right.farmId;
    if (farmDiff !== 0) {
      return farmDiff;
    }
    return left.itemId - right.itemId;
  });

  return {
    items: sorted.slice(0, limit).map(({ priority: _priority, ...item }) => item)
  };
}
