import { describe, expect, it } from 'vitest';
import { errorDtoI18nKey, isTranslationKey } from './error-dto-i18n-key';

describe('isTranslationKey', () => {
  it('accepts dot-separated ngx-translate keys', () => {
    expect(isTranslationKey('common.api_error.not_found')).toBe(true);
    expect(isTranslationKey('crops.errors.invalid_id')).toBe(true);
    expect(isTranslationKey('fertilizes.errors.invalid_id')).toBe(true);
  });

  it('rejects raw HTTP and human-readable messages', () => {
    expect(isTranslationKey('HTTP 404 Not Found')).toBe(false);
    expect(isTranslationKey('Http failure response for https://example.com: 404 Not Found')).toBe(
      false
    );
    expect(isTranslationKey('Resource not found')).toBe(false);
    expect(isTranslationKey('Unknown error')).toBe(false);
  });
});

describe('errorDtoI18nKey', () => {
  it('passes through existing i18n keys', () => {
    expect(errorDtoI18nKey({ message: 'common.api_error.not_found' })).toBe(
      'common.api_error.not_found'
    );
    expect(errorDtoI18nKey({ message: 'crops.errors.invalid_id' })).toBe('crops.errors.invalid_id');
  });

  it('maps raw 404 HTTP text to not_found key', () => {
    expect(
      errorDtoI18nKey({
        message: 'Http failure response for https://agrr.local/api/v1/masters/fertilizes/999: 404 Not Found'
      })
    ).toBe('common.api_error.not_found');
    expect(errorDtoI18nKey({ message: 'HTTP 404 Not Found' })).toBe('common.api_error.not_found');
  });

  it('maps raw 500 HTTP text to generic key', () => {
    expect(
      errorDtoI18nKey({
        message: 'Http failure response for https://agrr.local/api/v1/masters/pesticides/1: 500 Internal Server Error'
      })
    ).toBe('common.api_error.generic');
  });

  it('maps network failures to network key', () => {
    expect(
      errorDtoI18nKey({
        message: 'Http failure response for https://agrr.local/api/v1/masters/crops/1: 0 Unknown Error'
      })
    ).toBe('common.api_error.network');
  });

  it('maps unknown raw text to generic key', () => {
    expect(errorDtoI18nKey({ message: 'Something went wrong' })).toBe('common.api_error.generic');
  });
});
