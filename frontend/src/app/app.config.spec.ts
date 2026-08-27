import { ErrorHandler } from '@angular/core';
import { describe, expect, it } from 'vitest';

import { appConfig } from './app.config';
import { AgrrGlobalErrorHandler } from './core/errors/global-error.handler';

describe('appConfig', () => {
  it('registers AgrrGlobalErrorHandler as ErrorHandler', () => {
    const handlerProvider = appConfig.providers?.find(
      (provider) =>
        typeof provider === 'object' &&
        provider !== null &&
        'provide' in provider &&
        provider.provide === ErrorHandler
    );

    expect(handlerProvider).toEqual({
      provide: ErrorHandler,
      useClass: AgrrGlobalErrorHandler
    });
  });
});
