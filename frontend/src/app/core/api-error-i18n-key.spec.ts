import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import { BACKEND_WARMUP_I18N } from './backend-warmup/backend-warmup';
import { apiErrorI18nKey } from './api-error-i18n-key';

describe('apiErrorI18nKey', () => {
  it('maps 401 to unauthorized key', () => {
    expect(
      apiErrorI18nKey(new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' }))
    ).toBe('common.api_error.unauthorized');
  });

  it('maps 403 to forbidden key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 403, statusText: 'Forbidden' }))).toBe(
      'common.api_error.forbidden'
    );
  });

  it('maps 404 to not_found key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 404, statusText: 'Not Found' }))).toBe(
      'common.api_error.not_found'
    );
  });

  it('maps 409 to conflict key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 409, statusText: 'Conflict' }))).toBe(
      'common.api_error.conflict'
    );
  });

  it('maps status 0 to database warmup key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 0, statusText: 'Unknown Error' }))).toBe(
      BACKEND_WARMUP_I18N.database
    );
  });

  it('maps 501 to not_migrated key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 501, statusText: 'Not Implemented' }))).toBe(
      'common.api_error.not_migrated'
    );
  });

  it('maps 502 and bare 503 to backend warmup keys', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 502, statusText: 'Bad Gateway' }))).toBe(
      BACKEND_WARMUP_I18N.database
    );
    expect(
      apiErrorI18nKey(new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    ).toBe(BACKEND_WARMUP_I18N.database);
    expect(
      apiErrorI18nKey(
        new HttpErrorResponse({
          status: 503,
          error: { status: 'daemon_unavailable' }
        })
      )
    ).toBe(BACKEND_WARMUP_I18N.computeEngine);
  });

  it('maps entry-schedule weather_location_required 422 to dedicated i18n key', () => {
    expect(
      apiErrorI18nKey(
        new HttpErrorResponse({
          status: 422,
          error: { error: 'weather_location_required' }
        })
      )
    ).toBe('api.entry_schedule.errors.weather_location_required');
  });

  it('maps entry-schedule prediction_payload_missing 503 to prediction_failed key', () => {
    expect(
      apiErrorI18nKey(
        new HttpErrorResponse({
          status: 503,
          error: { error: 'prediction_payload_missing' }
        })
      )
    ).toBe('api.entry_schedule.errors.prediction_failed');
  });

  it('maps entry-schedule weather prediction failure 503 to prediction_failed key', () => {
    expect(
      apiErrorI18nKey(
        new HttpErrorResponse({
          status: 503,
          error: { error: 'daemon timeout' }
        })
      )
    ).toBe('api.entry_schedule.errors.prediction_failed');
  });

  it('maps other HTTP errors to generic key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 500, statusText: 'Server Error' }))).toBe(
      'common.api_error.generic'
    );
  });

  it('maps non-HTTP errors to generic key', () => {
    expect(apiErrorI18nKey(new Error('network'))).toBe('common.api_error.generic');
    expect(apiErrorI18nKey(undefined)).toBe('common.api_error.generic');
  });
});
