import { ErrorHandler, Injectable } from '@angular/core';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  handleError(error: unknown): void {
    console.error(error);
    // Log runtime errors without tearing down the shell. Bootstrap failure uses
    // renderBootstrapFailureFallback; AppFatalErrorService remains for explicit fatals.
  }
}
