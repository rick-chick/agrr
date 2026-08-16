import { beforeEach, describe, expect, it } from 'vitest';
import {
  consumePlanPostSaveOnboardingPending,
  dismissPlanPostSaveOnboarding,
  isPlanPostSaveOnboardingDismissed,
  markPlanPostSaveOnboardingPending,
  shouldShowPlanPostSaveOnboardingBanner
} from './plan-post-save-onboarding';

describe('plan-post-save-onboarding', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('marks and consumes pending onboarding for the saved plan', () => {
    markPlanPostSaveOnboardingPending(42);
    expect(consumePlanPostSaveOnboardingPending(42)).toBe(true);
    expect(consumePlanPostSaveOnboardingPending(42)).toBe(false);
  });

  it('does not consume pending onboarding for a different plan id', () => {
    markPlanPostSaveOnboardingPending(42);
    expect(consumePlanPostSaveOnboardingPending(99)).toBe(false);
    expect(consumePlanPostSaveOnboardingPending(42)).toBe(true);
  });

  it('persists dismiss state for the plan session', () => {
    dismissPlanPostSaveOnboarding(7);
    expect(isPlanPostSaveOnboardingDismissed(7)).toBe(true);
    expect(isPlanPostSaveOnboardingDismissed(8)).toBe(false);
  });

  it('shows banner only when pending matches and not dismissed', () => {
    markPlanPostSaveOnboardingPending(11);
    expect(shouldShowPlanPostSaveOnboardingBanner(11)).toBe(true);
    expect(shouldShowPlanPostSaveOnboardingBanner(11)).toBe(false);
  });

  it('does not show banner when dismissed before first visit', () => {
    markPlanPostSaveOnboardingPending(11);
    dismissPlanPostSaveOnboarding(11);
    expect(shouldShowPlanPostSaveOnboardingBanner(11)).toBe(false);
  });
});
