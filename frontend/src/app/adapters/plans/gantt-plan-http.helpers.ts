import { HttpErrorResponse } from '@angular/common/http';
import { apiErrorMessage } from '../../core/api-error-message';

export function extractGanttPlanHttpErrorMessage(error: HttpErrorResponse): string | undefined {
  return apiErrorMessage(error);
}
