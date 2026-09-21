import { HttpErrorResponse } from '@angular/common/http';
import {
  backendWarmupI18nKey,
  isBackendWarmupHttpError,
  isEntryScheduleWeatherHttpError
} from './backend-warmup/backend-warmup';

function entryScheduleWeatherApiErrorI18nKey(error: HttpErrorResponse): string | null {
  if (!isEntryScheduleWeatherHttpError(error)) {
    return null;
  }

  const body = error.error;
  const code =
    body != null && typeof body === 'object'
      ? (body as { error?: string }).error
      : undefined;

  if (error.status === 422 && code === 'weather_location_required') {
    return 'api.entry_schedule.errors.weather_location_required';
  }

  return 'api.entry_schedule.errors.prediction_failed';
}

/**
 * HTTP 失敗を画面用の ngx-translate キーへ正規化する（レスポンス本文の生表示を避ける）。
 */
export function apiErrorI18nKey(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    const entryScheduleKey = entryScheduleWeatherApiErrorI18nKey(error);
    if (entryScheduleKey) {
      return entryScheduleKey;
    }

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
