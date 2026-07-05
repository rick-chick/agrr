import { describe, expect, it } from 'vitest';
import {
  syncErrorRemediationRoute,
  syncErrorWizardLinkKey
} from './task-schedule-sync-remediation.mapper';
import {
  TASK_SCHEDULE_SYNC_CROP_STAGES_LINK_KEY,
  TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_GDD_DATE_NOT_FOUND_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_MISSING_GDD_TRIGGER_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_PLAN_CONTEXT_LINK_KEY
} from '../../domain/plans/task-schedule-sync-error-keys';

describe('syncErrorWizardLinkKey', () => {
  it('returns missing gdd trigger wizard link key', () => {
    expect(syncErrorWizardLinkKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER)).toBe(
      TASK_SCHEDULE_SYNC_MISSING_GDD_TRIGGER_WIZARD_LINK_KEY
    );
  });

  it('returns gdd date not found wizard link key', () => {
    expect(syncErrorWizardLinkKey(TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND)).toBe(
      TASK_SCHEDULE_SYNC_GDD_DATE_NOT_FOUND_WIZARD_LINK_KEY
    );
  });

  it('returns default crop wizard link key for other blueprint errors', () => {
    expect(syncErrorWizardLinkKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(
      TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY
    );
  });
});

describe('syncErrorRemediationRoute', () => {
  it('routes empty gdd progress to crop stages for a single crop', () => {
    expect(
      syncErrorRemediationRoute(
        TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
        7,
        'task_schedule',
        42,
        'Tomato',
        true
      )
    ).toEqual({
      linkKey: TASK_SCHEDULE_SYNC_CROP_STAGES_LINK_KEY,
      routerLink: ['/crops', 42, 'stages'],
      queryParams: { fromPlan: 7, returnTo: 'task_schedule' }
    });
  });

  it('routes empty gdd progress to plan context without a single crop target', () => {
    expect(
      syncErrorRemediationRoute(
        TASK_SCHEDULE_SYNC_ERROR_EMPTY_GDD_PROGRESS,
        7,
        'work',
        null,
        null,
        false
      )
    ).toEqual({
      linkKey: TASK_SCHEDULE_SYNC_PLAN_CONTEXT_LINK_KEY,
      routerLink: ['/plans', 7],
      queryParams: null
    });
  });

  it('routes missing gdd trigger to blueprint wizard with dedicated link copy', () => {
    expect(
      syncErrorRemediationRoute(
        'plans.task_schedules.sync_errors.missing_gdd_trigger',
        12,
        'task_schedule',
        79,
        'レタス',
        true
      )
    ).toEqual({
      linkKey: 'plans.task_schedules.sync_errors.missing_gdd_trigger_wizard_link',
      routerLink: ['/crops', 79, 'task_schedule_blueprints'],
      queryParams: { fromPlan: 12, returnTo: 'task_schedule' }
    });
  });
});
