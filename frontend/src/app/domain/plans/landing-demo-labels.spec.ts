import { describe, expect, it } from 'vitest';
import { buildLandingDemoLabels } from './landing-demo-labels';
import { LANDING_DEMO_I18N_KEYS, LANDING_DEMO_LABELS_FIXTURE } from './landing-demo-i18n.keys';

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
