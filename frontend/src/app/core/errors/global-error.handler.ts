import { ErrorHandler, Injectable } from '@angular/core';

import { renderFatalErrorFallback } from './render-fatal-error-fallback';

@Injectable()
export class AgrrGlobalErrorHandler implements ErrorHandler {
  handleError(error: unknown): void {
    console.error(error);
    const host = document.querySelector('app-root');
    if (!(host instanceof HTMLElement)) {
      return;
    }
    renderFatalErrorFallback(host, { kind: 'runtime' });
  }
}
