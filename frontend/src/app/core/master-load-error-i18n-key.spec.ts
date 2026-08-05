import { describe, expect, it } from 'vitest';

import { ErrorDto } from '../domain/shared/error.dto';
import { masterLoadErrorI18nKey } from './master-load-error-i18n-key';

describe('masterLoadErrorI18nKey', () => {
  it('passes through existing api_error i18n keys', () => {
    const dto: ErrorDto = { message: 'common.api_error.not_found' };
    expect(masterLoadErrorI18nKey(dto)).toBe('common.api_error.not_found');
  });

  it('maps Angular Http failure 404 message to not_found key', () => {
    const dto: ErrorDto = {
      message: 'Http failure response for https://example.com/api/fertilizes/999: 404 Not Found'
    };
    expect(masterLoadErrorI18nKey(dto)).toBe('common.api_error.not_found');
  });

  it('maps Angular Http failure 500 message to generic key', () => {
    const dto: ErrorDto = {
      message: 'Http failure response for https://example.com/api/pesticides/1: 500 Internal Server Error'
    };
    expect(masterLoadErrorI18nKey(dto)).toBe('common.api_error.generic');
  });

  it('maps httpStatus on dto when message is not an i18n key', () => {
    expect(masterLoadErrorI18nKey({ message: 'Server error', httpStatus: 503 })).toBe(
      'common.api_error.service_unavailable'
    );
  });

  it('maps errorCode not_found on dto', () => {
    expect(masterLoadErrorI18nKey({ message: 'missing', errorCode: 'not_found' })).toBe(
      'common.api_error.not_found'
    );
  });

  it('falls back to generic for unknown raw messages', () => {
    expect(masterLoadErrorI18nKey({ message: 'HTTP 404 Not Found' })).toBe(
      'common.api_error.not_found'
    );
    expect(masterLoadErrorI18nKey({ message: 'Something went wrong' })).toBe(
      'common.api_error.generic'
    );
  });
});
