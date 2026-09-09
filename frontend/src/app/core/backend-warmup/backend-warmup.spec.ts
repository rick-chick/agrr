import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import {
  BACKEND_WARMUP_I18N,
  backendWarmupI18nKey,
  backendWarmupI18nKeyFromMessage,
  isBackendWarmupHttpError,
  isBackendWarmupI18nKey,
  isComputeEngineWarmupHttpError
} from './backend-warmup';

describe('backendWarmup', () => {
  it('maps transient HTTP failures to database warmup key', () => {
    expect(backendWarmupI18nKey(new HttpErrorResponse({ status: 503 }))).toBe(
      BACKEND_WARMUP_I18N.database
    );
    expect(backendWarmupI18nKey(new HttpErrorResponse({ status: 502 }))).toBe(
      BACKEND_WARMUP_I18N.database
    );
    expect(backendWarmupI18nKey(new HttpErrorResponse({ status: 0 }))).toBe(
      BACKEND_WARMUP_I18N.database
    );
  });

  it('maps daemon failures to compute engine warmup key', () => {
    expect(
      backendWarmupI18nKey(
        new HttpErrorResponse({
          status: 503,
          error: { status: 'daemon_unavailable' }
        })
      )
    ).toBe(BACKEND_WARMUP_I18N.computeEngine);
  });

  it('detects warmup HTTP errors', () => {
    expect(isBackendWarmupHttpError(new HttpErrorResponse({ status: 503 }))).toBe(true);
    expect(isBackendWarmupHttpError(new HttpErrorResponse({ status: 500 }))).toBe(false);
  });

  it('detects compute engine warmup errors', () => {
    expect(
      isComputeEngineWarmupHttpError(
        new HttpErrorResponse({ status: 503, error: { error: 'agrr_daemon_not_running' } })
      )
    ).toBe(true);
  });

  it('recognizes backend warmup i18n keys', () => {
    expect(isBackendWarmupI18nKey(BACKEND_WARMUP_I18N.database)).toBe(true);
    expect(isBackendWarmupI18nKey('common.api_error.generic')).toBe(false);
  });

  it('maps raw error messages to backend warmup keys', () => {
    expect(
      backendWarmupI18nKeyFromMessage(
        'Http failure response for https://agrr.local/api/v1/masters/crops/1: 503 Service Unavailable'
      )
    ).toBe(BACKEND_WARMUP_I18N.database);
    expect(
      backendWarmupI18nKeyFromMessage(
        'Http failure response for https://agrr.local/api/v1/masters/crops/1: 0 Unknown Error'
      )
    ).toBe(BACKEND_WARMUP_I18N.database);
    expect(backendWarmupI18nKeyFromMessage('daemon_not_running')).toBe(
      BACKEND_WARMUP_I18N.computeEngine
    );
    expect(backendWarmupI18nKeyFromMessage('agrr daemon is not running')).toBe(
      BACKEND_WARMUP_I18N.computeEngine
    );
    expect(backendWarmupI18nKeyFromMessage('Something went wrong')).toBeNull();
  });
});
