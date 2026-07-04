import { describe, expect, it } from 'vitest';
import {
  applySyncFieldsToPlan,
  buildCropBannerContext,
  buildCropBannerEntries,
  buildTaskScheduleSyncBannerViewModel,
  mergeCropBannerContext,
  shouldOfferCropWizardLinks,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-presenter.helpers';
import {
  TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC
} from '../../core/task-schedule-sync-error-i18n';

describe('taskScheduleSyncViewPatch', () => {
  it('marks generating state as in-flight regeneration', () => {
    expect(taskScheduleSyncViewPatch('generating')).toEqual({
      regenerating: true,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('marks ready state for toast and reload', () => {
    expect(taskScheduleSyncViewPatch('ready')).toEqual({
      regenerating: false,
      toastI18nKey: 'plans.task_schedules.sync_updated',
      requestReload: true
    });
  });

  it('marks stale state as banner-only update', () => {
    expect(taskScheduleSyncViewPatch('stale')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: false
    });
  });

  it('marks failed state for reload without toast', () => {
    expect(taskScheduleSyncViewPatch('failed')).toEqual({
      regenerating: false,
      toastI18nKey: null,
      requestReload: true
    });
  });
});

describe('buildCropBannerContext', () => {
  it('returns empty context for no fields', () => {
    expect(buildCropBannerContext([])).toEqual({
      cropIds: [],
      cropNames: {}
    });
  });

  it('deduplicates positive crop ids', () => {
    expect(
      buildCropBannerContext([
        { crop_id: 3, crop_name: 'Tomato' },
        { crop_id: 3, crop_name: 'Tomato' },
        { crop_id: 5, crop_name: 'Lettuce' }
      ])
    ).toEqual({
      cropIds: [3, 5],
      cropNames: { 3: 'Tomato', 5: 'Lettuce' }
    });
  });

  it('omits non-positive crop ids and blank names from cropNames', () => {
    expect(
      buildCropBannerContext([
        { crop_id: 0, crop_name: 'Ignored' },
        { crop_id: -1, crop_name: 'Also ignored' },
        { crop_id: 2, crop_name: '  ' },
        { crop_id: 4, crop_name: '  Carrot  ' }
      ])
    ).toEqual({
      cropIds: [2, 4],
      cropNames: { 4: 'Carrot' }
    });
  });
});

describe('buildCropBannerEntries', () => {
  it('builds display labels from crop names with id fallback', () => {
    expect(buildCropBannerEntries([3, 3, 5], { 3: 'Tomato', 5: '  ' })).toEqual([
      { cropId: 3, label: 'Tomato' },
      { cropId: 5, label: '#5' }
    ]);
  });
});

describe('shouldOfferCropWizardLinks', () => {
  it('offers per-crop wizard links for generic errors with one or more crops', () => {
    const one = buildCropBannerEntries([1], { 1: 'A' });
    const two = buildCropBannerEntries([1, 2], { 1: 'A', 2: 'B' });
    expect(shouldOfferCropWizardLinks(TASK_SCHEDULE_SYNC_ERROR_GENERIC, one, false)).toBe(true);
    expect(shouldOfferCropWizardLinks(TASK_SCHEDULE_SYNC_ERROR_GENERIC, two, false)).toBe(true);
    expect(shouldOfferCropWizardLinks(TASK_SCHEDULE_SYNC_ERROR_GENERIC, [], false)).toBe(false);
  });

  it('offers wizard list for deficiency errors with multiple crops', () => {
    const two = buildCropBannerEntries([1, 2], { 1: 'A', 2: 'B' });
    expect(
      shouldOfferCropWizardLinks(
        'plans.task_schedules.sync_errors.missing_crop_blueprints',
        two,
        false
      )
    ).toBe(true);
  });

  it('offers wizard list for deficiency with one crop when target crop is unknown', () => {
    const one = buildCropBannerEntries([1], { 1: 'A' });
    expect(
      shouldOfferCropWizardLinks(
        'plans.task_schedules.sync_errors.missing_crop_templates',
        one,
        false
      )
    ).toBe(true);
  });

  it('uses single remediation link for deficiency with one known crop', () => {
    const one = buildCropBannerEntries([1], { 1: 'A' });
    expect(
      shouldOfferCropWizardLinks(
        'plans.task_schedules.sync_errors.missing_crop_blueprints',
        one,
        true
      )
    ).toBe(false);
    expect(
      shouldOfferCropWizardLinks(
        'plans.task_schedules.sync_errors.missing_crop_blueprints',
        one,
        false
      )
    ).toBe(true);
  });
});

describe('buildTaskScheduleSyncBannerViewModel', () => {
  it('lists wizard links for generic errors with plan crops', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_GENERIC,
      cropIds: [42, 99],
      cropNames: { 42: 'Tomato', 99: 'Lettuce' },
      planId: 7,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(true);
    expect(vm.cropBannerEntries).toHaveLength(2);
    expect(vm.cropWizardFragment).toBe('task-templates-heading');
    expect(vm.cropMasterQueryParams).toEqual({ fromPlan: 7 });
    expect(vm.showRetry).toBe(false);
  });

  it('uses single wizard link for targeted blueprint deficiency', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
      cropIds: [42, 99],
      cropNames: { 42: 'Tomato' },
      planId: 7,
      syncErrorCropId: 42,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(false);
    expect(vm.remediationLinkKey).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.cropsRouterLink).toEqual(['/crops', 42]);
  });
});

describe('mergeCropBannerContext', () => {
  it('falls back to plan remediation crops when fields are empty', () => {
    expect(
      mergeCropBannerContext([], [{ crop_id: 3, crop_name: 'Tomato' }])
    ).toEqual({
      cropIds: [3],
      cropNames: { 3: 'Tomato' }
    });
  });
});

describe('applySyncFieldsToPlan', () => {
  it('copies sync fields onto the plan snapshot', () => {
    const plan = {
      id: 7,
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    };

    expect(
      applySyncFieldsToPlan(plan, {
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.agrr_unavailable',
        syncErrorCropId: null
      })
    ).toEqual({
      id: 7,
      task_schedule_sync_state: 'failed',
      task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable',
      task_schedule_sync_error_crop_id: null
    });
  });

  it('copies sync error crop id from cable message', () => {
    const plan = {
      id: 7,
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    };

    expect(
      applySyncFieldsToPlan(plan, {
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
        syncErrorCropId: 15
      })
    ).toEqual({
      id: 7,
      task_schedule_sync_state: 'failed',
      task_schedule_sync_error: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
      task_schedule_sync_error_crop_id: 15
    });
  });
});
