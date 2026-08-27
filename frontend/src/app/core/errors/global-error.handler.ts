import { ErrorHandler, inject, Injectable } from '@angular/core';

import { AppFatalErrorService } from './app-fatal-error.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  private readonly fatalErrorService = inject(AppFatalErrorService);

  handleError(error: unknown): void {
    console.error(error);
    this.fatalErrorService.setFatalError(error);
  }
}
