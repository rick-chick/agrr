import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  UX_OPTIMIZATION_LIFECYCLE_EVENT,
  UX_RECOVERY_ACTION_EVENT
} from './ux-analytics.events';
import { GoogleAnalyticsService } from './google-analytics.service';
import { UxAnalyticsService } from './ux-analytics.service';

describe('UxAnalyticsService', () => {
  let service: UxAnalyticsService;
  let trackEvent: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    trackEvent = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        UxAnalyticsService,
        {
          provide: GoogleAnalyticsService,
          useValue: { trackEvent }
        }
      ]
    });
    service = TestBed.inject(UxAnalyticsService);
  });

  it('tracks ux_optimization_lifecycle completed without failure_category', () => {
    service.trackOptimizationLifecycle({
      phase: 'completed',
      flow: 'plans',
      job_scenario: 'J3'
    });

    expect(trackEvent).toHaveBeenCalledWith(UX_OPTIMIZATION_LIFECYCLE_EVENT, {
      phase: 'completed',
      flow: 'plans',
      job_scenario: 'J3'
    });
  });

  it('tracks ux_optimization_lifecycle failed with failure_category', () => {
    service.trackOptimizationLifecycle({
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'timeout'
    });

    expect(trackEvent).toHaveBeenCalledWith(UX_OPTIMIZATION_LIFECYCLE_EVENT, {
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'timeout'
    });
  });

  it('tracks ux_recovery_action with recovery_action and failure_category', () => {
    service.trackRecoveryAction({
      recovery_action: 'reload',
      failure_category: 'fetching_weather',
      flow: 'plans'
    });

    expect(trackEvent).toHaveBeenCalledWith(UX_RECOVERY_ACTION_EVENT, {
      recovery_action: 'reload',
      failure_category: 'fetching_weather',
      flow: 'plans'
    });
  });
});
