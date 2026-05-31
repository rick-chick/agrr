import { describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for crop create. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type CropsFormBundle = {
  index?: { title?: string; description?: string };
  new?: { title?: string };
  form?: {
    name_label?: string;
    variety_label?: string;
    area_per_unit_label?: string;
    revenue_per_area_label?: string;
    groups_label?: string;
    groups_placeholder?: string;
    is_reference_label?: string;
    submit_create?: string;
  };
};

function crops(bundle: { crops?: CropsFormBundle }): CropsFormBundle {
  return bundle.crops ?? {};
}

type RegionSelectKeys = 'label' | 'blank' | 'jp' | 'us' | 'in';

function regionSelect(bundle: unknown): Partial<Record<RegionSelectKeys, string>> {
  return (
    bundle as { shared?: { region_select?: Partial<Record<RegionSelectKeys, string>> } }
  ).shared?.region_select ?? {};
}

describe('crops/new i18n', () => {
  it('defines index.description in ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const c = crops(bundle);
      expect(c.index?.description, `${name}:index.description`).toBeTruthy();
    }
  });

  it('defines new.title and create form labels in ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const c = crops(bundle);
      expect(c.new?.title, `${name}:new.title`).toBeTruthy();
      expect(c.form?.name_label, `${name}:form.name_label`).toBeTruthy();
      expect(c.form?.submit_create, `${name}:form.submit_create`).toBeTruthy();
    }
  });

  it('uses English (not Japanese) for en locale create form strings', () => {
    const c = crops(en);
    const enStrings = [
      c.new?.title,
      c.form?.name_label,
      c.form?.variety_label,
      c.form?.area_per_unit_label,
      c.form?.revenue_per_area_label,
      c.form?.groups_label,
      c.form?.groups_placeholder,
      c.form?.is_reference_label,
      c.form?.submit_create
    ];
    for (const value of enStrings) {
      expect(value, `unexpected Japanese in en.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale create form strings', () => {
    const c = crops(inLocale);
    const inStrings = [
      c.new?.title,
      c.form?.name_label,
      c.form?.variety_label,
      c.form?.area_per_unit_label,
      c.form?.revenue_per_area_label,
      c.form?.groups_label,
      c.form?.groups_placeholder,
      c.form?.is_reference_label,
      c.form?.submit_create
    ];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('defines shared.region_select in ja, en, and in', () => {
    for (const bundle of [ja, en, inLocale]) {
      const rs = regionSelect(bundle);
      expect(rs['label']).toBeTruthy();
      expect(rs['blank']).toBeTruthy();
      expect(rs['jp']).toBeTruthy();
      expect(rs['us']).toBeTruthy();
      expect(rs['in']).toBeTruthy();
    }
  });

  it('uses English for shared.region_select in en locale', () => {
    const rs = regionSelect(en);
    for (const value of Object.values(rs)) {
      expect(value, `unexpected Japanese in en shared.region_select: ${value}`).not.toMatch(
        JAPANESE_UI
      );
    }
  });
});
