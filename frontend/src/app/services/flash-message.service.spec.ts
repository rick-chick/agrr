import { TestBed } from '@angular/core/testing';
import { provideTranslateParser, TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { AgrrTranslateParser } from '../core/i18n/agrr-translate.parser';
import { FlashMessageService } from './flash-message.service';

describe('FlashMessageService', () => {
  let service: FlashMessageService;
  let translate: TranslateService;

  beforeEach(async () => {
    vi.useFakeTimers();

    await TestBed.configureTestingModule({
      imports: [
        TranslateModule.forRoot({
          parser: provideTranslateParser(AgrrTranslateParser)
        })
      ],
      providers: [FlashMessageService]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      crops: {
        flash: {
          updated: 'Crop updated.'
        }
      }
    });
    translate.use('en');

    service = TestBed.inject(FlashMessageService);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('auto-dismisses success messages after 3 seconds by default', () => {
    service.show({ type: 'success', text: 'crops.flash.updated' });

    expect(service.messages()).toHaveLength(1);

    vi.advanceTimersByTime(2999);
    expect(service.messages()).toHaveLength(1);

    vi.advanceTimersByTime(1);
    expect(service.messages()).toHaveLength(0);
  });

  it('does not auto-dismiss error messages', () => {
    service.show({ type: 'error', text: 'Something went wrong.' });

    vi.advanceTimersByTime(10_000);
    expect(service.messages()).toHaveLength(1);
  });

  it('cancels the auto-dismiss timer when remove is called manually', () => {
    service.show({ type: 'success', text: 'crops.flash.updated' });
    const id = service.messages()[0]?.id;
    expect(id).toBeTruthy();

    service.remove(id!);

    expect(service.messages()).toHaveLength(0);

    vi.advanceTimersByTime(10_000);
    expect(service.messages()).toHaveLength(0);
  });
});
