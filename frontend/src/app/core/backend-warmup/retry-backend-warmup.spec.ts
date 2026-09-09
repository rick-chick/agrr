import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it, vi } from 'vitest';
import { defer, firstValueFrom, of, throwError } from 'rxjs';
import { retryOnBackendWarmup } from './retry-backend-warmup';

describe('retryOnBackendWarmup', () => {
  it('retries transient 503 then succeeds', async () => {
    vi.useFakeTimers();
    let attempts = 0;

    const promise = firstValueFrom(
      defer(() => {
        attempts += 1;
        if (attempts < 3) {
          return throwError(() => new HttpErrorResponse({ status: 503 }));
        }
        return of('ok');
      }).pipe(retryOnBackendWarmup())
    );

    await vi.advanceTimersByTimeAsync(4000);
    await expect(promise).resolves.toBe('ok');
    expect(attempts).toBe(3);
    vi.useRealTimers();
  });

  it('passes through without retry when disabled for SSR prerender', async () => {
    let attempts = 0;

    await expect(
      firstValueFrom(
        defer(() => {
          attempts += 1;
          return throwError(() => new HttpErrorResponse({ status: 503 }));
        }).pipe(retryOnBackendWarmup({ enabled: false }))
      )
    ).rejects.toBeTruthy();

    expect(attempts).toBe(1);
  });

  it('does not retry non-warmup errors', async () => {
    let attempts = 0;

    await expect(
      firstValueFrom(
        defer(() => {
          attempts += 1;
          return throwError(() => new HttpErrorResponse({ status: 500 }));
        }).pipe(retryOnBackendWarmup())
      )
    ).rejects.toBeTruthy();

    expect(attempts).toBe(1);
  });
});
