import { identity, MonoTypeOperatorFunction, timer, throwError } from 'rxjs';
import { retry } from 'rxjs/operators';
import { isBackendWarmupHttpError } from './backend-warmup';

const BACKEND_WARMUP_MAX_RETRIES = 30;
const BACKEND_WARMUP_RETRY_DELAY_MS = 2000;

type RetryOnBackendWarmupOptions = {
  enabled?: boolean;
};

export function retryOnBackendWarmup<T>(
  options: RetryOnBackendWarmupOptions = {}
): MonoTypeOperatorFunction<T> {
  if (options.enabled === false) {
    return identity;
  }

  return retry({
    delay: (error, retryCount) => {
      if (retryCount > BACKEND_WARMUP_MAX_RETRIES || !isBackendWarmupHttpError(error)) {
        return throwError(() => error);
      }
      return timer(BACKEND_WARMUP_RETRY_DELAY_MS);
    }
  });
}
