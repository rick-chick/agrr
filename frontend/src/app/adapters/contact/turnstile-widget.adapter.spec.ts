import { PLATFORM_ID } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { TranslateService } from '@ngx-translate/core';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { TurnstileWidgetAdapter } from './turnstile-widget.adapter';

describe('TurnstileWidgetAdapter', () => {
  afterEach(() => {
    document.querySelectorAll('script[data-turnstile="true"]').forEach((el) => el.remove());
    delete (window as Window & { turnstile?: unknown }).turnstile;
  });

  it('reports unavailable on server platform', () => {
    TestBed.configureTestingModule({
      providers: [
        TurnstileWidgetAdapter,
        { provide: PLATFORM_ID, useValue: 'server' },
        { provide: TranslateService, useValue: { currentLang: 'ja' } }
      ]
    });
    const adapter = TestBed.inject(TurnstileWidgetAdapter);
    const onUnavailable = vi.fn();
    adapter.render(document.createElement('div'), {
      onToken: vi.fn(),
      onExpired: vi.fn(),
      onUnavailable
    });
    expect(onUnavailable).toHaveBeenCalled();
  });

  it('calls turnstile.render with sitekey and response-field false', async () => {
    const render = vi.fn(() => 'widget-1');
    const reset = vi.fn();
    const remove = vi.fn();
    (window as Window & { turnstile?: unknown }).turnstile = { render, reset, remove };

    TestBed.configureTestingModule({
      providers: [
        TurnstileWidgetAdapter,
        { provide: PLATFORM_ID, useValue: 'browser' },
        { provide: TranslateService, useValue: { currentLang: 'in' } }
      ]
    });
    const adapter = TestBed.inject(TurnstileWidgetAdapter);
    const host = document.createElement('div');
    adapter.render(host, {
      onToken: vi.fn(),
      onExpired: vi.fn(),
      onUnavailable: vi.fn()
    });

    await vi.waitFor(() => expect(render).toHaveBeenCalledTimes(1));
    const firstCall = render.mock.calls[0] as unknown as [HTMLElement, Record<string, unknown>];
    const options = firstCall[1];
    expect(options['sitekey']).toBe('1x00000000000000000000AA');
    expect(options['response-field']).toBe(false);
    expect(options['language']).toBe('hi');
    adapter.reset();
    expect(reset).toHaveBeenCalledWith('widget-1');
  });
});
