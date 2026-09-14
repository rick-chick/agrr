import { HttpErrorResponse } from '@angular/common/http';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { PLATFORM_ID } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { firstValueFrom } from 'rxjs';

import { ApiService } from './api.service';

function configureApiService(platformId: 'browser' | 'server'): {
  service: ApiService;
  httpMock: HttpTestingController;
} {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ApiService,
      provideHttpClient(),
      provideHttpClientTesting(),
      { provide: PLATFORM_ID, useValue: platformId },
    ],
  });

  return {
    service: TestBed.inject(ApiService),
    httpMock: TestBed.inject(HttpTestingController),
  };
}

describe('ApiService', () => {
  afterEach(() => {
    TestBed.inject(HttpTestingController).verify();
  });

  describe('get() with backend warmup retry', () => {
    it('retries transient 503 in browser then succeeds', async () => {
      vi.useFakeTimers();
      const { service, httpMock } = configureApiService('browser');

      const promise = firstValueFrom(service.get<{ ok: boolean }>('/api/v1/auth/me'));

      httpMock.expectOne('/api/v1/auth/me').flush(null, {
        status: 503,
        statusText: 'Service Unavailable',
      });

      await vi.advanceTimersByTimeAsync(2000);
      httpMock.expectOne('/api/v1/auth/me').flush(null, {
        status: 503,
        statusText: 'Service Unavailable',
      });

      await vi.advanceTimersByTimeAsync(2000);
      httpMock.expectOne('/api/v1/auth/me').flush({ ok: true });

      await expect(promise).resolves.toEqual({ ok: true });
      vi.useRealTimers();
    });

    it('does not retry GET during SSR prerender', async () => {
      const { service, httpMock } = configureApiService('server');

      const promise = firstValueFrom(service.get('/api/v1/auth/me'));

      httpMock.expectOne('/api/v1/auth/me').flush(null, {
        status: 503,
        statusText: 'Service Unavailable',
      });

      await expect(promise).rejects.toBeInstanceOf(HttpErrorResponse);
      httpMock.expectNone('/api/v1/auth/me');
    });
  });

  describe('post() without backend warmup retry', () => {
    it('fails immediately on first 503 in browser', async () => {
      const { service, httpMock } = configureApiService('browser');

      const promise = firstValueFrom(service.post('/api/v1/plans', { name: 'Test' }));

      httpMock.expectOne('/api/v1/plans').flush(null, {
        status: 503,
        statusText: 'Service Unavailable',
      });

      await expect(promise).rejects.toBeInstanceOf(HttpErrorResponse);
      httpMock.expectNone('/api/v1/plans');
    });
  });
});
