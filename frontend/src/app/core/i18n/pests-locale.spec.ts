import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in UI strings for pest masters. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

type PestsBundle = {
  index?: {
    title?: string;
    description?: string;
    new_pest?: string;
    empty?: { title?: string; description?: string; button?: string };
    actions?: { edit?: string; delete?: string };
  };
  new?: { title?: string };
  edit?: { title?: string };
  form?: {
    name_label?: string;
    name_scientific_label?: string;
    family_label?: string;
    order_label?: string;
    description_label?: string;
    occurrence_season_label?: string;
    submit_create?: string;
    submit_update?: string;
  };
  show?: {
    name?: string;
    region?: string;
    edit?: string;
    delete?: string;
    back_to_list?: string;
    confirm_delete?: string;
  };
  errors?: { invalid_id?: string };
  undo?: { toast?: string };
};

function pests(bundle: JsonRecord): PestsBundle {
  return (bundle['pests'] as PestsBundle) ?? {};
}

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

const CATALOG_KEYS = [
  'pests.index.title',
  'pests.index.description',
  'pests.index.new_pest',
  'pests.index.empty.title',
  'pests.index.empty.description',
  'pests.new.title',
  'pests.edit.title',
  'pests.form.name_label',
  'pests.form.submit_create',
  'pests.form.submit_update',
  'pests.show.region',
  'pests.show.confirm_delete',
  'pests.errors.invalid_id',
  'pests.undo.toast'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('pests master i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }

      it('edit.title uses {{name}} placeholder', () => {
        const title = pests(catalog).edit?.title ?? '';
        expect(title).toContain('{{name}}');
        expect(title).not.toMatch(/%\{name\}/);
      });
    });
  }

  it('index.description mentions cultivation plans in ja', () => {
    expect(pests(ja as JsonRecord).index?.description).toContain('作付け計画');
  });

  it('uses English (not Japanese) for en locale index and form strings', () => {
    const p = pests(en as JsonRecord);
    const enStrings = [
      p.index?.title,
      p.index?.description,
      p.new?.title,
      p.form?.name_label,
      p.form?.submit_create,
      p.errors?.invalid_id
    ];
    for (const value of enStrings) {
      expect(value, `unexpected Japanese in en.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale index strings', () => {
    const p = pests(inLocale as JsonRecord);
    const inStrings = [p.index?.title, p.index?.description, p.new?.title];
    for (const value of inStrings) {
      expect(value, `unexpected Japanese in in.json: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
