import { HttpErrorResponse } from '@angular/common/http';

function errorBody(error: unknown): Record<string, unknown> | null {
  if (error instanceof HttpErrorResponse) {
    const body = error.error;
    if (body != null && typeof body === 'object' && !Array.isArray(body)) {
      return body as Record<string, unknown>;
    }
  }
  if (error != null && typeof error === 'object' && !Array.isArray(error)) {
    const nested = (error as { error?: unknown }).error;
    if (nested != null && typeof nested === 'object' && !Array.isArray(nested)) {
      return nested as Record<string, unknown>;
    }
    return error as Record<string, unknown>;
  }
  return null;
}

export function apiErrorCode(error: unknown): string | null {
  const body = errorBody(error);
  if (!body) {
    return null;
  }
  const code = body['error_code'];
  return typeof code === 'string' && code.length > 0 ? code : null;
}
