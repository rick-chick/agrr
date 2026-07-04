import { describe, expect, it } from 'vitest';
import {
  cropMasterLinkFragmentForSyncError,
  cropMasterRemediationLinkKey,
  cropWizardFragmentForSyncError,
  syncErrorDetailTranslateKey,
  syncErrorDetailTranslateParams,
  TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY,
  TASK_SCHEDULE_SYNC_ERROR_GENERIC,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
  TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES
} from './task-schedule-sync-error-i18n';

describe('syncErrorDetailTranslateKey', () => {
  it('uses single-crop detail key for generic errors with one plan crop', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, 'トマト', 1)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_single`
    );
  });

  it('uses no-crop detail key when plan crops are unknown', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, null, 0)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_no_plan_crops`
    );
  });

  it('uses multi-crop detail key for generic errors with multiple plan crops', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_GENERIC, null, 2)).toBe(
      `${TASK_SCHEDULE_SYNC_ERROR_GENERIC}_multi`
    );
  });

  it('uses named detail keys when crop name is known', () => {
    expect(
      syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS, 'トマト')
    ).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS}_named`);
  });

  it('falls back to base key without crop name', () => {
    expect(syncErrorDetailTranslateKey(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS, null)).toBe(
      TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS
    );
  });
});

describe('syncErrorDetailTranslateParams', () => {
  it('passes cropName only when present', () => {
    expect(syncErrorDetailTranslateParams('トマト')).toEqual({ cropName: 'トマト' });
    expect(syncErrorDetailTranslateParams(null)).toEqual({});
  });
});

describe('cropMasterLinkFragmentForSyncError', () => {
  it('maps template errors to task templates anchor', () => {
    expect(cropMasterLinkFragmentForSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES)).toBe(
      'task-templates-heading'
    );
  });

  it('maps blueprint errors to blueprints anchor', () => {
    expect(cropMasterLinkFragmentForSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(
      'blueprints-heading'
    );
  });

  it('maps general template errors to blueprints anchor', () => {
    expect(
      cropMasterLinkFragmentForSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES)
    ).toBe('blueprints-heading');
  });
});

describe('cropWizardFragmentForSyncError', () => {
  it('defaults generic errors to step 1 anchor', () => {
    expect(cropWizardFragmentForSyncError(TASK_SCHEDULE_SYNC_ERROR_GENERIC)).toBe(
      'task-templates-heading'
    );
  });

  it('uses blueprint anchor for blueprint deficiency errors', () => {
    expect(cropWizardFragmentForSyncError(TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS)).toBe(
      'blueprints-heading'
    );
  });
});

describe('cropMasterRemediationLinkKey', () => {
  it('uses shared wizard link when crop name or id is known', () => {
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
        'failed',
        'トマト',
        true
      )
    ).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_BLUEPRINTS,
        'failed',
        null,
        true
      )
    ).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
  });

  it('uses list link when crop is unknown', () => {
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES,
        'failed',
        null,
        false
      )
    ).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_CROP_TEMPLATES}_link`);
  });

  it('uses shared wizard link for general template errors with crop context', () => {
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
        'failed',
        'Tomato',
        true
      )
    ).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
        'failed',
        null,
        true
      )
    ).toBe(TASK_SCHEDULE_SYNC_CROP_WIZARD_LINK_KEY);
    expect(
      cropMasterRemediationLinkKey(
        TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES,
        'failed',
        null,
        false
      )
    ).toBe(`${TASK_SCHEDULE_SYNC_ERROR_MISSING_GENERAL_TEMPLATES}_link`);
  });
});
