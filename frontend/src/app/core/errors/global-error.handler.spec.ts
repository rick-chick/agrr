import { TestBed } from '@angular/core/testing';
import { ErrorHandler } from '@angular/core';

import { AppFatalErrorService } from './app-fatal-error.service';
import { GlobalErrorHandler } from './global-error.handler';

describe('GlobalErrorHandler', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        { provide: ErrorHandler, useClass: GlobalErrorHandler },
        AppFatalErrorService
      ]
    });
  });

  it('records fatal errors for the app shell fallback', () => {
    const handler = TestBed.inject(ErrorHandler) as GlobalErrorHandler;
    const fatalErrorService = TestBed.inject(AppFatalErrorService);
    const error = new Error('runtime boom');

    handler.handleError(error);

    expect(fatalErrorService.hasFatalError()).toBe(true);
  });
});
