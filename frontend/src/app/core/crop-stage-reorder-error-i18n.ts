import { HttpErrorResponse } from '@angular/common/http';
import { apiErrorI18nKey } from './api-error-i18n-key';

export function cropStageReorderErrorI18nKey(error: unknown): string {
  if (error instanceof HttpErrorResponse && error.status === 422) {
    return 'crops.errors.stage_order_conflict';
  }
  return apiErrorI18nKey(error);
}
