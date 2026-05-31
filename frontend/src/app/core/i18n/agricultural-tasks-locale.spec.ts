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
    region_label?: string;
    region_blank?: string;
    required_tools_hint?: string;
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

  it('uses Hindi (not Japanese) for in locale list and create UI strings', () => {
    const t = tasks(inLocale);
    const inStrings = [
      t.index?.title,
      t.index?.new_agricultural_task,
      t.index?.empty?.title,
      t.new?.title,
      t.form?.region_label,
      t.form?.required_tools_hint
    ];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('defines shared.region_select in ja, en, and in', () => {
    for (const bundle of [ja, en, inLocale]) {
      const rs = (bundle as { shared?: { region_select?: { label?: string } } }).shared?.region_select;
      expect(rs?.label).toBeTruthy();
    }
  });
});
