import { describe, expect, it } from 'vitest';
import {
  ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS,
  BLUEPRINT_WIZARD_SYNC_ERRORS,
  isActionableDataDeficiencySyncError,
  isBlueprintWizardSyncError,
  isPlanContextSyncError,
  normalizeTaskScheduleSyncError,
  PLAN_CONTEXT_SYNC_ERRORS,
  resolveCropName,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS
} from './task-schedule-sync-error';
import {
  TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER,
  TASK_SCHEDULE_SYNC_ERROR_PREFIX
} from './task-schedule-sync-error-keys';

describe('task-schedule-sync-error-keys', () => {
  it('uses a shared i18n prefix for all error keys', () => {
    expect(TASK_SCHEDULE_SYNC_ERROR_GENERIC.startsWith(TASK_SCHEDULE_SYNC_ERROR_PREFIX)).toBe(true);
    expect(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES.startsWith(TASK_SCHEDULE_SYNC_ERROR_PREFIX)).toBe(
      true
    );
  });
});

describe('normalizeTaskScheduleSyncError', () => {
  it('keeps known i18n keys', () => {
    const key = 'plans.task_schedules.sync_errors.agrr_unavailable';
    expect(normalizeTaskScheduleSyncError(key)).toBe(key);
  });

  // Parity with Rust `normalize_stored_sync_error` (task_schedule_sync_error.rs):
  // unknown raw messages map to GENERIC; known i18n keys pass through unchanged.
  it('maps unknown raw messages to generic key (Rust normalize_stored_sync_error parity)', () => {
    expect(normalizeTaskScheduleSyncError('worker timeout')).toBe(TASK_SCHEDULE_SYNC_ERROR_GENERIC);
  });

  it('returns null for empty values', () => {
    expect(normalizeTaskScheduleSyncError(null)).toBeNull();
    expect(normalizeTaskScheduleSyncError('')).toBeNull();
  });
});

describe('isActionableDataDeficiencySyncError', () => {
  it('returns true for template, blueprint, and general deficiency keys', () => {
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES)).toBe(
      true
    );
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(
      true
    );
    expect(
      isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES)
    ).toBe(true);
    expect(
      isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS)
    ).toBe(true);
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_GDD_TRIGGER)).toBe(
      true
    );
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_GDD_DATE_NOT_FOUND)).toBe(
      true
    );
  });

  it('returns false for transient errors', () => {
    expect(isActionableDataDeficiencySyncError(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(false);
    expect(isActionableDataDeficiencySyncError(null)).toBe(false);
  });
});

describe('sync error classification sets', () => {
  it('shares blueprint wizard errors with actionable deficiency errors', () => {
    expect(BLUEPRINT_WIZARD_SYNC_ERRORS).toBe(ACTIONABLE_DATA_DEFICIENCY_SYNC_ERRORS);
  });

  it('classifies plan context errors', () => {
    expect(PLAN_CONTEXT_SYNC_ERRORS.has(TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER)).toBe(true);
    expect(PLAN_CONTEXT_SYNC_ERRORS.has(TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE)).toBe(true);
    expect(PLAN_CONTEXT_SYNC_ERRORS.has(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(true);
    expect(PLAN_CONTEXT_SYNC_ERRORS.has(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES)).toBe(
      false
    );
  });
});

describe('isBlueprintWizardSyncError', () => {
  it('matches actionable data deficiency errors', () => {
    expect(isBlueprintWizardSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(true);
    expect(isBlueprintWizardSyncError(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(false);
    expect(isBlueprintWizardSyncError(null)).toBe(false);
  });
});

describe('isPlanContextSyncError', () => {
  it('returns true for plan context deficiency keys', () => {
    expect(isPlanContextSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_WEATHER)).toBe(true);
    expect(isPlanContextSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_START_DATE)).toBe(true);
    expect(isPlanContextSyncError(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(true);
  });

  it('returns false for blueprint wizard errors', () => {
    expect(isPlanContextSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES)).toBe(false);
    expect(isPlanContextSyncError(null)).toBe(false);
  });
});

describe('resolveCropName', () => {
  it('returns trimmed crop name for known id', () => {
    expect(resolveCropName(3, { 3: ' トマト ' })).toBe('トマト');
  });

  it('returns null when name is missing', () => {
    expect(resolveCropName(3, {})).toBeNull();
  });
});
