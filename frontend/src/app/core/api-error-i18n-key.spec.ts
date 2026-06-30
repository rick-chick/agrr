import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
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

  it('maps status 0 to network key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 0, statusText: 'Unknown Error' }))).toBe(
      'common.api_error.network'
    );
  });

  it('maps 501 to not_migrated key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 501, statusText: 'Not Implemented' }))).toBe(
      'common.api_error.not_migrated'
    );
  });

  it('maps 502 and 503 to service_unavailable key', () => {
    expect(apiErrorI18nKey(new HttpErrorResponse({ status: 502, statusText: 'Bad Gateway' }))).toBe(
      'common.api_error.service_unavailable'
    );
    expect(
      apiErrorI18nKey(new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    ).toBe('common.api_error.service_unavailable');
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
