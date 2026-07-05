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
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS
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
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.cropMasterQueryParams).toEqual({ fromPlan: 7 });
    expect(vm.showRetry).toBe(false);
  });

  it('uses single wizard link for targeted blueprint deficiency', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
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
    expect(vm.cropMasterQueryParams).toEqual({ fromPlan: 7 });
    expect(vm.showRetry).toBe(false);
  });

  it('shows named blueprint deficiency detail and remediation params', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
      cropIds: [],
      cropNames: { 42: 'Tomato' },
      planId: 0,
      syncErrorCropId: 42,
      regenerateError: null
    });
    expect(vm.syncErrorDetailKey).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS}_named`);
    expect(vm.syncErrorDetailParams).toEqual({ cropName: 'Tomato' });
    expect(vm.remediationLinkParams).toEqual({ cropName: 'Tomato' });
    expect(vm.showRetry).toBe(false);
  });

  it('prefers syncErrorCropId over multiple cropIds for remediation link', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
      cropIds: [42, 99],
      cropNames: {},
      planId: 0,
      syncErrorCropId: 15,
      regenerateError: null
    });
    expect(vm.cropsRouterLink).toEqual(['/crops', 15]);
    expect(vm.remediationLinkParams).toEqual({ cropName: '#15' });
  });

  it('links to crop list when templates are missing without a target crop', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
      cropIds: [],
      cropNames: {},
      planId: 0,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(false);
    expect(vm.remediationLinkKey).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES}_link`);
    expect(vm.cropsRouterLink).toBe('/crops');
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.showRetry).toBe(false);
  });

  it('uses single remediation link for one known crop on template deficiency', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
      cropIds: [42],
      cropNames: {},
      planId: 0,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(false);
    expect(vm.remediationLinkKey).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(vm.cropsRouterLink).toEqual(['/crops', 42]);
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.remediationLinkParams).toEqual({ cropName: '#42' });
  });

  it('shows generic single-crop wizard links', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_GENERIC,
      cropIds: [42],
      cropNames: { 42: 'Tomato' },
      planId: 7,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(true);
    expect(vm.cropBannerEntries).toEqual([{ cropId: 42, label: 'Tomato' }]);
    expect(vm.syncErrorDetailKey).toBe(`${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_single`);
    expect(vm.syncErrorDetailParams).toEqual({ cropName: 'Tomato' });
    expect(vm.showRetry).toBe(false);
    expect(vm.showGenericPlanLink).toBe(false);
    expect(vm.remediationLinkKey).toBeNull();
  });

  it('lists wizard links for generic error with multiple crops', () => {
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
    expect(vm.cropBannerEntries).toEqual([
      { cropId: 42, label: 'Tomato' },
      { cropId: 99, label: 'Lettuce' }
    ]);
    expect(vm.syncErrorDetailKey).toBe(`${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_multi`);
    expect(vm.showRetry).toBe(false);
    expect(vm.showGenericPlanLink).toBe(false);
    expect(vm.remediationLinkKey).toBeNull();
  });

  it('offers plan link when generic error has no crop context', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_GENERIC,
      cropIds: [],
      cropNames: {},
      planId: 7,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showGenericPlanLink).toBe(true);
    expect(vm.syncErrorDetailKey).toBe(`${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_no_plan_crops`);
    expect(vm.showCropWizardLinks).toBe(false);
    expect(vm.showRetry).toBe(false);
  });

  it('includes sync error crop in generic wizard links when plan crops are unknown', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_GENERIC,
      cropIds: [],
      cropNames: {},
      planId: 0,
      syncErrorCropId: 42,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(true);
    expect(vm.cropBannerEntries).toEqual([{ cropId: 42, label: '#42' }]);
    expect(vm.showRetry).toBe(false);
  });

  it('shows missing general blueprints named detail and single remediation link', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
      cropIds: [],
      cropNames: { 42: 'Tomato' },
      planId: 0,
      syncErrorCropId: 42,
      regenerateError: null
    });
    expect(vm.syncErrorDetailKey).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS}_named`
    );
    expect(vm.syncErrorDetailParams).toEqual({ cropName: 'Tomato' });
    expect(vm.showCropWizardLinks).toBe(false);
    expect(vm.remediationLinkKey).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(vm.cropsRouterLink).toEqual(['/crops', 42]);
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.remediationLinkParams).toEqual({ cropName: 'Tomato' });
    expect(vm.showRetry).toBe(false);
  });

  it('uses base missing general blueprints key when crop name is unknown', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS,
      cropIds: [],
      cropNames: {},
      planId: 0,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.syncErrorDetailKey).toBe(TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS);
    expect(vm.syncErrorDetailParams).toEqual({});
    expect(vm.remediationLinkKey).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_BLUEPRINTS}_link`
    );
    expect(vm.cropsRouterLink).toBe('/crops');
  });

  it('lists wizard links for multiple crops when blueprints are missing', () => {
    const vm = buildTaskScheduleSyncBannerViewModel({
      syncState: 'failed',
      syncError: TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
      cropIds: [42, 99],
      cropNames: { 42: 'Tomato', 99: 'Lettuce' },
      planId: 7,
      syncErrorCropId: null,
      regenerateError: null
    });
    expect(vm.showCropWizardLinks).toBe(true);
    expect(vm.cropBannerEntries).toEqual([
      { cropId: 42, label: 'Tomato' },
      { cropId: 99, label: 'Lettuce' }
    ]);
    expect(vm.cropWizardFragment).toBe('blueprints-heading');
    expect(vm.cropMasterQueryParams).toEqual({ fromPlan: 7 });
    expect(vm.showRetry).toBe(false);
    expect(vm.remediationLinkKey).toBeNull();
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
