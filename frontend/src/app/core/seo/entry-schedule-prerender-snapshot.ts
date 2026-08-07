import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import type { EntryScheduleCropShowResponse } from '../../domain/entry-schedule/entry-schedule';
import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  type EntrySchedulePrerenderCrop,
} from './entry-schedule-prerender-catalog';

type JsonRecord = Record<string, unknown>;
type EntryScheduleLocale = 'ja' | 'en' | 'in';

const LOCALE_CATALOGS: Record<EntryScheduleLocale, JsonRecord> = {
  ja: ja as JsonRecord,
  en: en as JsonRecord,
  in: inLocale as JsonRecord,
};

function getNested(obj: JsonRecord, path: string): string {
  const value = path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
  return typeof value === 'string' ? value : '';
}

function interpolate(template: string, params: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_match, key: string) => params[key] ?? '');
}

function resolveLocale(locale?: string): EntryScheduleLocale {
  if (locale === 'en' || locale === 'in' || locale === 'ja') {
    return locale;
  }
  return 'ja';
}

/** Static body copy for build-time prerender when the public API is unavailable. */
export function buildEntrySchedulePrerenderSnapshot(
  crop: EntrySchedulePrerenderCrop,
  locale?: string
): EntryScheduleCropShowResponse {
  const lang = resolveLocale(locale);
  const catalog = LOCALE_CATALOGS[lang];

  const reasonSummary = interpolate(
    getNested(catalog, 'pages.entry_schedule_detail.description'),
    { cropName: crop.name }
  );

  return {
    farm: {
      id: ENTRY_SCHEDULE_PRERENDER_CATALOG.defaultFarmId,
      name: '埼玉',
      latitude: 35.8569,
      longitude: 139.6489,
      region: ENTRY_SCHEDULE_PRERENDER_CATALOG.region,
    },
    prediction: {
      chart_calendar_year: new Date().getFullYear(),
    },
    crop: {
      id: crop.cropId,
      name: crop.name,
      eligible: true,
      sowing_summary: null,
      transplant_summary: null,
      reason_summary: reasonSummary,
      labels: {
        sowing: getNested(catalog, 'api.entry_schedule.label.sowing'),
        transplanting: getNested(catalog, 'api.entry_schedule.label.transplanting'),
      },
      sowing_windows: [],
      transplant_windows: [],
      reason_parts: {},
      sowing_stage_id: null,
      transplant_stage_id: null,
      crop_stages: [],
      entry_disclaimer: getNested(catalog, 'api.entry_schedule.disclaimer.short'),
    },
  };
}
