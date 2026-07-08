import { HttpErrorResponse } from '@angular/common/http';

export function extractGanttPlanHttpErrorMessage(error: HttpErrorResponse): string | undefined {
  if (error?.error?.message) {
    return String(error.error.message);
  }
  return error.message;
}
