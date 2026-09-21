import { HttpErrorResponse } from '@angular/common/http';

export const BACKEND_WARMUP_I18N = {
  database: 'common.backend_warmup.database',
  computeEngine: 'common.backend_warmup.compute_engine'
} as const;

type BackendWarmupI18nKey = (typeof BACKEND_WARMUP_I18N)[keyof typeof BACKEND_WARMUP_I18N];

const BACKEND_WARMUP_KEY_SET = new Set<string>(Object.values(BACKEND_WARMUP_I18N));

export function isBackendWarmupI18nKey(value: string | null | undefined): value is BackendWarmupI18nKey {
  return value != null && BACKEND_WARMUP_KEY_SET.has(value);
}

function errorBodyText(error: HttpErrorResponse): string {
  const body = error.error;
  if (typeof body === 'string') {
    return body.toLowerCase();
  }
  if (body != null && typeof body === 'object') {
    try {
      return JSON.stringify(body).toLowerCase();
    } catch {
      return '';
    }
  }
  return '';
}

export function isComputeEngineWarmupMessage(message: string): boolean {
  const lowered = message.toLowerCase();
  return (
    lowered.includes('daemon_unavailable') ||
    lowered.includes('agrr_daemon') ||
    lowered.includes('daemon_not_running') ||
    lowered.includes('agrr daemon')
  );
}

export function isBackendWarmupMessage(message: string): boolean {
  const lowered = message.toLowerCase();
  if (
    /\b503\b/.test(lowered) ||
    /\b502\b/.test(lowered) ||
    lowered.includes('service unavailable') ||
    /\b0 unknown error\b/.test(lowered) ||
    /: 0 /.test(lowered)
  ) {
    return true;
  }
  return isComputeEngineWarmupMessage(lowered);
}

export function backendWarmupI18nKeyFromMessage(message: string): BackendWarmupI18nKey | null {
  if (!isBackendWarmupMessage(message)) {
    return null;
  }
  if (isComputeEngineWarmupMessage(message)) {
    return BACKEND_WARMUP_I18N.computeEngine;
  }
  return BACKEND_WARMUP_I18N.database;
}

export function isComputeEngineWarmupHttpError(error: unknown): boolean {
  if (!(error instanceof HttpErrorResponse)) {
    return false;
  }

  const text = errorBodyText(error);
  return isComputeEngineWarmupMessage(text);
}

function httpErrorBodyCode(error: HttpErrorResponse): string | null {
  const body = error.error;
  if (body == null || typeof body !== 'object') {
    return null;
  }
  const code = (body as { error?: unknown }).error;
  return typeof code === 'string' && code.length > 0 ? code : null;
}

/** Entry-schedule weather failures return explicit JSON error codes — not backend warmup. */
export function isEntryScheduleWeatherHttpError(error: unknown): boolean {
  if (!(error instanceof HttpErrorResponse)) {
    return false;
  }

  const code = httpErrorBodyCode(error);
  if (!code) {
    return false;
  }

  if (error.status === 422 && code === 'weather_location_required') {
    return true;
  }

  if (error.status === 503) {
    if (code === 'prediction_payload_missing') {
      return true;
    }
    return !isComputeEngineWarmupMessage(code);
  }

  return false;
}

export function isBackendWarmupHttpError(error: unknown): boolean {
  if (!(error instanceof HttpErrorResponse)) {
    return false;
  }

  if (isEntryScheduleWeatherHttpError(error)) {
    return false;
  }

  if (error.status === 502 || error.status === 503 || error.status === 0) {
    return true;
  }

  return isComputeEngineWarmupHttpError(error);
}

export function backendWarmupI18nKey(error: unknown): BackendWarmupI18nKey {
  if (isComputeEngineWarmupHttpError(error)) {
    return BACKEND_WARMUP_I18N.computeEngine;
  }
  return BACKEND_WARMUP_I18N.database;
}
