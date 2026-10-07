import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import {
  apiErrorCode,
  apiFieldErrors,
  apiErrorHasMessage,
  apiErrorMessage,
  apiErrorMessages,
  apiValidationFieldErrors
} from './api-error-message';

describe('api-error-message', () => {
  it('reads string errors from HttpErrorResponse body', () => {
    const err = new HttpErrorResponse({
      status: 422,
      error: { errors: ['k'] }
    });
    expect(apiErrorMessages(err)).toEqual(['k']);
    expect(apiErrorMessage(err)).toBe('k');
  });

  it('trims and drops blank-only error elements', () => {
    const err = new HttpErrorResponse({
      status: 422,
      error: { errors: ['  k  ', ' '] }
    });
    expect(apiErrorMessages(err)).toEqual(['k']);
  });

  it('joins multiple errors with comma space', () => {
    const err = new HttpErrorResponse({
      status: 422,
      error: { errors: ['a', 'b'] }
    });
    expect(apiErrorMessage(err)).toBe('a, b');
  });

  it('uses status i18n key when errors array is empty', () => {
    const err = new HttpErrorResponse({ status: 404, error: { errors: [] } });
    expect(apiErrorMessage(err)).toBe('common.api_error.not_found');
  });

  it('does not read legacy error key', () => {
    const err = new HttpErrorResponse({ status: 422, error: { error: 'a' } });
    expect(apiErrorMessage(err)).toBe('common.api_error.generic');
  });

  it('does not read legacy success/message shape', () => {
    const err = new HttpErrorResponse({
      status: 500,
      error: { success: false, message: 'm' }
    });
    expect(apiErrorMessage(err)).toBe('common.api_error.generic');
  });

  it('prefers errors over legacy error when both present', () => {
    const err = new HttpErrorResponse({
      status: 422,
      error: { errors: ['a'], error: 'b' }
    });
    expect(apiErrorMessage(err)).toBe('a');
  });

  it('maps 409 to conflict i18n key', () => {
    const err = new HttpErrorResponse({
      status: 409,
      error: { errors: ['stale_record'] }
    });
    expect(apiErrorMessage(err)).toBe('common.api_error.conflict');
  });

  it('maps bare 404 to not_found', () => {
    const err = new HttpErrorResponse({ status: 404 });
    expect(apiErrorMessage(err)).toBe('common.api_error.not_found');
  });

  it('returns empty messages for map or object-array errors', () => {
    const mapErr = new HttpErrorResponse({
      status: 422,
      error: { errors: { name: ['x'] } }
    });
    const objErr = new HttpErrorResponse({
      status: 422,
      error: { errors: [{ path: 'a', message: 'b' }] }
    });
    expect(apiErrorMessages(mapErr)).toEqual([]);
    expect(apiErrorMessage(mapErr)).toBe('common.api_error.generic');
    expect(apiErrorMessages(objErr)).toEqual([]);
    expect(apiErrorMessage(objErr)).toBe('common.api_error.generic');
  });

  it('handles non-HTTP errors', () => {
    expect(apiErrorMessage(new Error('boom'))).toBe('boom');
    expect(apiErrorMessage(new Error(''))).toBe('common.api_error.generic');
    expect(apiErrorMessage(null)).toBe('common.api_error.generic');
  });

  it('apiErrorHasMessage matches errors elements only', () => {
    const err = new HttpErrorResponse({
      status: 422,
      error: { errors: ['weather_location_required'] }
    });
    expect(apiErrorHasMessage(err, 'weather_location_required')).toBe(true);
    expect(apiErrorHasMessage(err, 'other')).toBe(false);
    const legacy = new HttpErrorResponse({
      status: 422,
      error: { error: 'weather_location_required' }
    });
    expect(apiErrorHasMessage(legacy, 'weather_location_required')).toBe(false);
  });

  it('reads error_code and field_errors', () => {
    const codeErr = new HttpErrorResponse({
      status: 403,
      error: { error_code: 'insufficient_scope' }
    });
    expect(apiErrorCode(codeErr)).toBe('insufficient_scope');
    expect(apiErrorCode(new HttpErrorResponse({ status: 403, error: {} }))).toBeNull();
    expect(apiErrorCode(new HttpErrorResponse({ status: 403, error: { error_code: '' } }))).toBeNull();

    const fieldErr = new HttpErrorResponse({
      status: 422,
      error: { field_errors: { name: ['x'] } }
    });
    expect(apiFieldErrors(fieldErr)).toEqual({ name: ['x'] });
    expect(
      apiFieldErrors(
        new HttpErrorResponse({ status: 422, error: { field_errors: { name: 'x' } } })
      )
    ).toBeNull();
    expect(
      apiFieldErrors(new HttpErrorResponse({ status: 422, error: { errors: { name: ['x'] } } }))
    ).toBeNull();
  });

  it('apiValidationFieldErrors prefers field_errors then legacy errors map (S1)', () => {
    const fieldErr = new HttpErrorResponse({
      status: 422,
      error: { field_errors: { name: ['a'] }, errors: { title: ['b'] } }
    });
    expect(apiValidationFieldErrors(fieldErr)).toEqual({ name: ['a'] });

    const legacyMap = new HttpErrorResponse({
      status: 422,
      error: { errors: { title: ['required'] } }
    });
    expect(apiValidationFieldErrors(legacyMap)).toEqual({ title: ['required'] });
  });
});
