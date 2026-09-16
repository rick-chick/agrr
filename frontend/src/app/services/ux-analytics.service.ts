import { Injectable, inject } from '@angular/core';
import {
  OptimizationLifecycleParams,
  RecoveryActionParams,
  UX_OPTIMIZATION_LIFECYCLE_EVENT,
  UX_RECOVERY_ACTION_EVENT
} from './ux-analytics.events';
import { GoogleAnalyticsService } from './google-analytics.service';

@Injectable({ providedIn: 'root' })
export class UxAnalyticsService {
  private readonly googleAnalytics = inject(GoogleAnalyticsService);

  trackOptimizationLifecycle(params: OptimizationLifecycleParams): void {
    const payload: Record<string, string> = {
      phase: params.phase,
      flow: params.flow,
      job_scenario: params.job_scenario
    };
    if (params.failure_category) {
      payload['failure_category'] = params.failure_category;
    }
    this.googleAnalytics.trackEvent(UX_OPTIMIZATION_LIFECYCLE_EVENT, payload);
  }

  trackRecoveryAction(params: RecoveryActionParams): void {
    this.googleAnalytics.trackEvent(UX_RECOVERY_ACTION_EVENT, {
      recovery_action: params.recovery_action,
      failure_category: params.failure_category,
      flow: params.flow
    });
  }
}
