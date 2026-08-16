import { beforeEach, describe, expect, it } from 'vitest';
import {
  clearPlanPostSaveOnboardingSession,
  dismissPlanPostSaveBanner,
  markPlanPostSaveOnboarding,
  shouldShowPlanPostSaveBanner
} from './plan-post-save-onboarding-session';

describe('plan-post-save-onboarding-session', () => {
  beforeEach(() => {
    clearPlanPostSaveOnboardingSession();
  });

  it('shows banner for plan marked after save', () => {
    markPlanPostSaveOnboarding(42);
    expect(shouldShowPlanPostSaveBanner(42)).toBe(true);
    expect(shouldShowPlanPostSaveBanner(99)).toBe(false);
  });

  it('hides banner after dismiss in the same session', () => {
    markPlanPostSaveOnboarding(42);
    dismissPlanPostSaveBanner(42);
    expect(shouldShowPlanPostSaveBanner(42)).toBe(false);
  });

  it('tracks multiple pending plans independently', () => {
    markPlanPostSaveOnboarding(10);
    markPlanPostSaveOnboarding(20);
    dismissPlanPostSaveBanner(10);

    expect(shouldShowPlanPostSaveBanner(10)).toBe(false);
    expect(shouldShowPlanPostSaveBanner(20)).toBe(true);
  });
});
