import { ErrorHandler } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';

import { AgrrGlobalErrorHandler } from './global-error.handler';
import { FATAL_ERROR_FALLBACK_ROOT_ID } from './render-fatal-error-fallback';

describe('AgrrGlobalErrorHandler', () => {
  let host: HTMLElement;

  beforeEach(() => {
    localStorage.setItem('agrr.app.lang', 'ja');
    host = document.createElement('app-root');
    document.body.appendChild(host);
    TestBed.configureTestingModule({
      providers: [{ provide: ErrorHandler, useClass: AgrrGlobalErrorHandler }]
    });
  });

  afterEach(() => {
    host.remove();
  });

  it('renders runtime fallback into app-root on handleError', () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const handler = TestBed.inject(ErrorHandler);

    handler.handleError(new Error('boom'));

    expect(consoleError).toHaveBeenCalled();
    expect(host.querySelector(`#${FATAL_ERROR_FALLBACK_ROOT_ID}`)).not.toBeNull();
    expect(host.textContent).toContain('予期しないエラーが発生しました');

    consoleError.mockRestore();
  });
});
