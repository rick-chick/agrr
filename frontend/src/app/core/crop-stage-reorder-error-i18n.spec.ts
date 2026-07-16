import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import { cropStageReorderErrorI18nKey } from './crop-stage-reorder-error-i18n';

describe('cropStageReorderErrorI18nKey', () => {
  it('maps 422 to stage order conflict key', () => {
    expect(
      cropStageReorderErrorI18nKey(
        new HttpErrorResponse({ status: 422, statusText: 'Unprocessable Entity', error: { errors: ['invalid'] } })
      )
    ).toBe('crops.errors.stage_order_conflict');
  });

  it('maps other HTTP errors via apiErrorI18nKey', () => {
    expect(
      cropStageReorderErrorI18nKey(new HttpErrorResponse({ status: 500, statusText: 'Server Error' }))
    ).toBe('common.api_error.generic');
  });

  it('maps non-HTTP errors to generic key', () => {
    expect(cropStageReorderErrorI18nKey(new Error('network'))).toBe('common.api_error.generic');
  });
});
