import { describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in Hindi UI strings for task list/create. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type AgriculturalTasksBundle = {
  index?: {
    title?: string;
    description?: string;
    skill_label?: string;
    new_agricultural_task?: string;
    empty?: { title?: string; description?: string; button?: string };
  };
  new?: { title?: string };
  form?: {
    name_label?: string;
    description_label?: string;
    time_per_sqm_label?: string;
    weather_dependency_label?: string;
    skill_level_label?: string;
    task_type_label?: string;
    submit_create?: string;
    region_label?: string;
    region_blank?: string;
    required_tools_hint?: string;
  };
  show?: {
    weather_dependency_low?: string;
    weather_dependency_medium?: string;
    weather_dependency_high?: string;
    skill_level_beginner?: string;
    skill_level_intermediate?: string;
    skill_level_advanced?: string;
  };
};

function tasks(bundle: { agricultural_tasks?: AgriculturalTasksBundle }): AgriculturalTasksBundle {
  return bundle.agricultural_tasks ?? {};
}

describe('agricultural_tasks index and new i18n', () => {
  it('defines index.skill_label and new.title in ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const t = tasks(bundle);
      expect(t.index?.skill_label, `${name}:index.skill_label`).toBeTruthy();
      expect(t.new?.title, `${name}:new.title`).toBeTruthy();
      expect(t.index?.description, `${name}:index.description`).toBeTruthy();
    }
  });

  it('defines create form labels in ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const f = tasks(bundle).form;
      expect(f?.name_label, `${name}:form.name_label`).toBeTruthy();
      expect(f?.description_label, `${name}:form.description_label`).toBeTruthy();
      expect(f?.time_per_sqm_label, `${name}:form.time_per_sqm_label`).toBeTruthy();
      expect(f?.weather_dependency_label, `${name}:form.weather_dependency_label`).toBeTruthy();
      expect(f?.skill_level_label, `${name}:form.skill_level_label`).toBeTruthy();
      expect(f?.task_type_label, `${name}:form.task_type_label`).toBeTruthy();
      expect(f?.submit_create, `${name}:form.submit_create`).toBeTruthy();
    }
  });

  it('uses English (not Japanese) for en locale list and create UI strings', () => {
    const t = tasks(en);
    const enStrings = [
      t.index?.title,
      t.index?.description,
      t.index?.skill_label,
      t.index?.new_agricultural_task,
      t.new?.title,
      t.form?.name_label,
      t.form?.description_label,
      t.form?.time_per_sqm_label,
      t.form?.weather_dependency_label,
      t.form?.skill_level_label,
      t.form?.task_type_label,
      t.form?.submit_create,
      t.show?.weather_dependency_low,
      t.show?.skill_level_beginner
    ];
    for (const value of enStrings) {
      expect(value, `unexpected Japanese in en.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale list and create UI strings', () => {
    const t = tasks(inLocale);
    const inStrings = [
      t.index?.title,
      t.index?.new_agricultural_task,
      t.index?.empty?.title,
      t.new?.title,
      t.form?.name_label,
      t.form?.description_label,
      t.form?.time_per_sqm_label,
      t.form?.weather_dependency_label,
      t.form?.skill_level_label,
      t.form?.task_type_label,
      t.form?.submit_create,
      t.form?.region_label,
      t.form?.required_tools_hint,
      t.show?.weather_dependency_low,
      t.show?.skill_level_beginner
    ];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
