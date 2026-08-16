import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';

const HARVEST_LABEL_PATTERN = /収穫|harvest|कटाई/i;

export function matchesHarvestLabel(label: string): boolean {
  const trimmed = label.trim();
  if (!trimmed) {
    return false;
  }
  return HARVEST_LABEL_PATTERN.test(trimmed);
}

function harvestStageName(item: TaskScheduleItem): string {
  return item.details?.stage?.name ?? item.stage_name ?? '';
}

export function isHarvestTaskItem(item: TaskScheduleItem): boolean {
  if (item.category !== 'general') {
    return false;
  }
  if (matchesHarvestLabel(item.name)) {
    return true;
  }
  return matchesHarvestLabel(harvestStageName(item));
}

export function isHarvestWorkRow(row: WorkDayListRowDto): boolean {
  return isHarvestTaskItem(row.item);
}

export function isHarvestWorkRecord(record: WorkRecord): boolean {
  if (matchesHarvestLabel(record.name)) {
    return true;
  }
  const scheduleName = record.task_schedule_item?.name ?? '';
  return matchesHarvestLabel(scheduleName);
}
