import { TestBed } from '@angular/core/testing';
import { ErrorHandler } from '@angular/core';

import { GlobalErrorHandler } from './global-error.handler';

describe('GlobalErrorHandler', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [{ provide: ErrorHandler, useClass: GlobalErrorHandler }]
    });
  });

  it('logs runtime errors without activating the shell overlay', () => {
    const handler = TestBed.inject(ErrorHandler) as GlobalErrorHandler;
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const error = new Error('runtime boom');

    handler.handleError(error);

    expect(consoleSpy).toHaveBeenCalledWith(error);
    consoleSpy.mockRestore();
  });
});
