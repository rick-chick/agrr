import { HttpErrorResponse } from '@angular/common/http';
import { apiErrorI18nKey } from './api-error-i18n-key';
import { apiErrorMessagesFromBody } from './api-error-body';

const GENERIC_KEY = 'common.api_error.generic';

export function apiErrorMessages(err: unknown): string[] {
  if (err instanceof HttpErrorResponse) {
    return apiErrorMessagesFromBody(err.error);
  }
  return [];
}

export function apiErrorMessage(err: unknown): string {
  if (err instanceof HttpErrorResponse) {
    if (err.status === 409) {
      return 'common.api_error.conflict';
    }
    const messages = apiErrorMessages(err);
    if (messages.length > 0) {
      return messages.join(', ');
    }
    return apiErrorI18nKey(err);
  }
  if (err instanceof Error) {
    const msg = err.message?.trim();
    return msg.length > 0 ? msg : GENERIC_KEY;
  }
  return GENERIC_KEY;
}

export function apiErrorHasMessage(err: unknown, key: string): boolean {
  return apiErrorMessages(err).includes(key);
}

export function apiErrorCode(err: unknown): string | null {
  if (!(err instanceof HttpErrorResponse)) {
    return null;
  }
  const body = err.error;
  if (!isRecord(body)) {
    return null;
  }
  const code = body['error_code'];
  return typeof code === 'string' && code.length > 0 ? code : null;
}

export function apiFieldErrors(err: unknown): Record<string, string[]> | null {
  if (!(err instanceof HttpErrorResponse)) {
    return null;
  }
  const body = err.error;
  if (!isRecord(body)) {
    return null;
  }
  const fieldErrors = body['field_errors'];
  if (fieldErrors == null || typeof fieldErrors !== 'object' || Array.isArray(fieldErrors)) {
    return null;
  }
  const result: Record<string, string[]> = {};
  for (const [key, value] of Object.entries(fieldErrors)) {
    if (!Array.isArray(value)) {
      return null;
    }
    const strings: string[] = [];
    for (const item of value) {
      if (typeof item !== 'string') {
        return null;
      }
      strings.push(item);
    }
    result[key] = strings;
  }
  return result;
}

/** `field_errors` first, then legacy 422 body where `errors` is a field → messages map (S1). */
export function apiValidationFieldErrors(err: unknown): Record<string, string[]> | null {
  const fromFieldErrors = apiFieldErrors(err);
  if (fromFieldErrors && Object.keys(fromFieldErrors).length > 0) {
    return fromFieldErrors;
  }
  if (!(err instanceof HttpErrorResponse) || err.status !== 422) {
    return null;
  }
  const body = err.error;
  if (!isRecord(body)) {
    return null;
  }
  const errors = body['errors'];
  if (errors == null || typeof errors !== 'object' || Array.isArray(errors)) {
    return null;
  }
  const result: Record<string, string[]> = {};
  for (const [key, value] of Object.entries(errors)) {
    if (!Array.isArray(value)) {
      return null;
    }
    const strings: string[] = [];
    for (const item of value) {
      if (typeof item !== 'string') {
        return null;
      }
      strings.push(item);
    }
    result[key] = strings;
  }
  return Object.keys(result).length > 0 ? result : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}
