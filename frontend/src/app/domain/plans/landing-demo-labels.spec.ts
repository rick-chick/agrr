import { describe, expect, it } from 'vitest';
import { buildHomeDemoTitleParams, buildLandingDemoLabels } from './landing-demo-labels';
import {
  HOME_DEMO_SECTION_I18N_KEYS,
  LANDING_DEMO_I18N_KEYS,
  LANDING_DEMO_LABELS_FIXTURE
} from './landing-demo-i18n.keys';

describe('buildHomeDemoTitleParams', () => {
  it('maps schedule, separator, and preview from translate.instant', () => {
    const params = buildHomeDemoTitleParams({
      instant: (key: string) => `tr:${key}`
    });
    expect(params.schedule).toBe(`tr:${HOME_DEMO_SECTION_I18N_KEYS.schedule}`);
    expect(params.preview).toBe(`tr:${HOME_DEMO_SECTION_I18N_KEYS.preview}`);
    expect(params.separator).toBe(`tr:${HOME_DEMO_SECTION_I18N_KEYS.separator}`);
  });
});

describe('buildLandingDemoLabels', () => {
  it('maps translate.instant results to label fields', () => {
    const instant = (key: string) => `tr:${key}`;
    const labels = buildLandingDemoLabels({ instant });

    expect(labels.planName).toBe(`tr:${LANDING_DEMO_I18N_KEYS.planName}`);
    expect(labels.cropTomato).toBe(`tr:${LANDING_DEMO_I18N_KEYS.cropTomato}`);
  });

  it('falls back to English fixture when translations are missing', () => {
    const labels = buildLandingDemoLabels({
      instant: (key) => key
    });

    expect(labels).toEqual(LANDING_DEMO_LABELS_FIXTURE);
  });
});
