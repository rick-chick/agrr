import { HttpErrorResponse } from '@angular/common/http';

export function isAuthMeSessionUnavailableError(error: unknown): boolean {
  return error instanceof HttpErrorResponse && error.status >= 500;
}

export function isAuthMeUnauthenticatedError(error: unknown): boolean {
  return error instanceof HttpErrorResponse && error.status === 401;
}
