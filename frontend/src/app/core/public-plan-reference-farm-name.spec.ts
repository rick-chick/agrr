import { describe, expect, it } from 'vitest';

import ja from '../../assets/i18n/ja.json';
import inLocale from '../../assets/i18n/in.json';
import en from '../../assets/i18n/en.json';
import { localizePublicPlanReferenceFarmName } from './public-plan-reference-farm-name';

type JsonRecord = Record<string, unknown>;

function catalogInstant(lang: 'ja' | 'en' | 'in') {
  const catalog = (lang === 'ja' ? ja : lang === 'en' ? en : inLocale) as JsonRecord;
  const farms = (catalog['public_plans'] as JsonRecord)['reference_farms'] as JsonRecord;
  return (key: string) => {
    const slug = key.replace('public_plans.reference_farms.', '');
    const value = farms[slug];
    return typeof value === 'string' ? value : key;
  };
}

describe('localizePublicPlanReferenceFarmName', () => {
  it('shows Japanese prefecture name for Tokyo in ja locale', () => {
    const name = localizePublicPlanReferenceFarmName(
      { name: 'mojibake', latitude: 35.6762, longitude: 139.6503, region: 'jp' },
      catalogInstant('ja')
    );
    expect(name).toBe('東京');
  });

  it('maps legacy Punjab stub to Hindi label in in locale', () => {
    const name = localizePublicPlanReferenceFarmName(
      { name: 'Punjab', latitude: 30.9010, longitude: 75.8573, region: 'in' },
      catalogInstant('in')
    );
    expect(name).toBe('लुधियाना, पंजाब');
  });

  it('maps legacy Punjab stub to English label in en locale', () => {
    const name = localizePublicPlanReferenceFarmName(
      { name: 'Punjab', latitude: 30.9010, longitude: 75.8573, region: 'in' },
      catalogInstant('en')
    );
    expect(name).toBe('Ludhiana, Punjab');
  });

  it('falls back to API name when coordinates are missing', () => {
    const name = localizePublicPlanReferenceFarmName(
      { name: 'Test Farm', region: 'jp' },
      catalogInstant('ja')
    );
    expect(name).toBe('Test Farm');
  });

  it('falls back to API name when coordinates are unknown', () => {
    const name = localizePublicPlanReferenceFarmName(
      { name: 'Custom Farm', latitude: 0, longitude: 0, region: 'jp' },
      catalogInstant('ja')
    );
    expect(name).toBe('Custom Farm');
  });
});
