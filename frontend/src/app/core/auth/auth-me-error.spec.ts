import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import {
  isAuthMeSessionUnavailableError,
  isAuthMeUnauthenticatedError
} from './auth-me-error';

describe('auth-me-error', () => {
  it('treats 5xx as session unavailable', () => {
    expect(
      isAuthMeSessionUnavailableError(new HttpErrorResponse({ status: 500, statusText: 'Error' }))
    ).toBe(true);
    expect(
      isAuthMeSessionUnavailableError(new HttpErrorResponse({ status: 503, statusText: 'Error' }))
    ).toBe(true);
  });

  it('does not treat 401 as session unavailable', () => {
    expect(
      isAuthMeSessionUnavailableError(new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' }))
    ).toBe(false);
  });

  it('treats only 401 as unauthenticated', () => {
    expect(
      isAuthMeUnauthenticatedError(new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' }))
    ).toBe(true);
    expect(
      isAuthMeUnauthenticatedError(new HttpErrorResponse({ status: 500, statusText: 'Error' }))
    ).toBe(false);
  });
});
