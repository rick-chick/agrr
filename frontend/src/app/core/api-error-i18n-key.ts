import { HttpErrorResponse } from '@angular/common/http';
import { backendWarmupI18nKey, isBackendWarmupHttpError } from './backend-warmup/backend-warmup';

/**
 * HTTP 失敗を画面用の ngx-translate キーへ正規化する（レスポンス本文の生表示を避ける）。
 */
export function apiErrorI18nKey(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    if (error.status === 401) {
      return 'common.api_error.unauthorized';
    }
    if (error.status === 403) {
      return 'common.api_error.forbidden';
    }
    if (error.status === 404) {
      return 'common.api_error.not_found';
    }
    if (error.status === 409) {
      return 'common.api_error.conflict';
    }
    if (error.status === 501) {
      return 'common.api_error.not_migrated';
    }
    if (isBackendWarmupHttpError(error)) {
      return backendWarmupI18nKey(error);
    }
    return 'common.api_error.generic';
  }
  return 'common.api_error.generic';
}
