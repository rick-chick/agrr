import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import {
  blueprintRegenerateErrorShowsRetry,
  cropBlueprintRegenerateErrorI18nKey
} from './crop-blueprint-regenerate-error-i18n';

describe('cropBlueprintRegenerateErrorI18nKey', () => {
  it('maps error_code from response body to blueprint error i18n key', () => {
    const error = new HttpErrorResponse({
      status: 422,
      error: { error: 'msg', error_code: 'missing_blueprints' }
    });
    expect(cropBlueprintRegenerateErrorI18nKey(error)).toBe(
      'crops.show.blueprint_errors.missing_blueprints'
    );
  });

  it('maps 503 to ai_unavailable when error_code is absent', () => {
    const error = new HttpErrorResponse({ status: 503, error: { error: 'down' } });
    expect(cropBlueprintRegenerateErrorI18nKey(error)).toBe(
      'crops.show.blueprint_errors.ai_unavailable'
    );
  });

  it('falls back to generic for unknown errors', () => {
    expect(cropBlueprintRegenerateErrorI18nKey(new Error('x'))).toBe(
      'crops.show.blueprint_errors.generic'
    );
  });
});

describe('blueprintRegenerateErrorShowsRetry', () => {
  it('returns false for readiness-blocking errors', () => {
    expect(
      blueprintRegenerateErrorShowsRetry('crops.show.blueprint_errors.missing_blueprints')
    ).toBe(false);
    expect(
      blueprintRegenerateErrorShowsRetry('crops.show.blueprint_errors.missing_agrr_requirement')
    ).toBe(false);
  });

  it('returns true for retriable blueprint regenerate errors', () => {
    expect(blueprintRegenerateErrorShowsRetry('crops.show.blueprint_errors.generic')).toBe(true);
    expect(blueprintRegenerateErrorShowsRetry('crops.show.blueprint_errors.ai_unavailable')).toBe(
      true
    );
  });
});
