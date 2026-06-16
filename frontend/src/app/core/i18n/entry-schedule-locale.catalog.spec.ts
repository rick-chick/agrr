import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

const ENTRY_SCHEDULE_UI_KEYS = [
  'entrySchedule.title',
  'entrySchedule.detailTitle',
  'entrySchedule.back',
  'entrySchedule.loading',
  'entrySchedule.retry',
  'entrySchedule.error',
  'entrySchedule.timeout',
  'entrySchedule.noFarms',
  'entrySchedule.selectFarm',
  'entrySchedule.show',
  'entrySchedule.blockSelectFarm',
  'entrySchedule.predictionFresh',
  'entrySchedule.predictionUntil',
  'entrySchedule.eligibleYes',
  'entrySchedule.eligibleNo',
  'entrySchedule.whyTitle',
  'entrySchedule.collapse',
  'entrySchedule.expand',
  'entrySchedule.table.detail',
  'entrySchedule.loadMore',
  'entrySchedule.listDisclaimer',
  'entrySchedule.viz.ganttTitle',
  'entrySchedule.viz.detailGanttIntro',
  'entrySchedule.viz.ganttAria',
  'entrySchedule.viz.axisYear',
  'entrySchedule.viz.bandStartHint',
  'entrySchedule.viz.noWindow',
  'entrySchedule.viz.monthTick',
  'entrySchedule.viz.detailGanttFoot',
  'entrySchedule.viz.listChartIntro',
  'entrySchedule.viz.listChartFoot',
  'entrySchedule.viz.sowBand',
  'entrySchedule.viz.transplantBand',
  'entrySchedule.windows',
  'entrySchedule.phases',
  'entrySchedule.timeline',
  'entrySchedule.nextTask',
  'entrySchedule.nextTaskPlaceholder',
  'entrySchedule.stages'
] as const;

const ENTRY_SCHEDULE_API_KEYS = [
  'api.entry_schedule.label.sowing',
  'api.entry_schedule.label.transplanting',
  'api.entry_schedule.phase.label.sowing',
  'api.entry_schedule.phase.label.nursery',
  'api.entry_schedule.phase.label.transplant',
  'api.entry_schedule.phase.label.harvest',
  'api.entry_schedule.phase.empty.ineligible',
  'api.entry_schedule.phase.empty.no_sowing_window',
  'api.entry_schedule.phase.empty.no_transplant_window',
  'api.entry_schedule.phase.empty.nursery_gap',
  'api.entry_schedule.phase.empty.no_weather_end',
  'api.entry_schedule.flow.summary',
  'api.entry_schedule.flow.summary_fallback',
  'api.entry_schedule.flow.detail_chunk',
  'api.entry_schedule.flow.month_range',
  'api.entry_schedule.timeline.month_summary',
  'api.entry_schedule.disclaimer.short',
  'api.entry_schedule.reason.list',
  'api.entry_schedule.reason.agrr',
  'api.entry_schedule.reason.agrr_failed.generic',
  'api.entry_schedule.reason.agrr_failed.daemon_unavailable',
  'api.entry_schedule.reason.agrr_failed.execution_failed',
  'api.entry_schedule.reason.agrr_failed.invalid_response',
  'api.entry_schedule.reason.agrr_failed.insufficient_weather',
  'api.entry_schedule.reason.agrr_failed.disabled',
  'api.entry_schedule.reason.agrr_failed.crop_requirement_error',
  'api.entry_schedule.errors.weather_location_required',
  'api.entry_schedule.errors.prediction_failed'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('entry schedule i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of [...ENTRY_SCHEDULE_UI_KEYS, ...ENTRY_SCHEDULE_API_KEYS]) {
        it(`defines ${key} as human-readable text`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const text = value as string;
          expect(text.length).toBeGreaterThan(0);
          expect(text).not.toBe(key);
          expect(text).not.toMatch(/^api\.entry_schedule\./);
          expect(text).not.toMatch(/^entrySchedule\./);
        });
      }
    });
  }
});
