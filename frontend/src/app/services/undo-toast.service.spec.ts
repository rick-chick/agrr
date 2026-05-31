import { TestBed } from '@angular/core/testing';
import { provideTranslateParser, TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach } from 'vitest';

import { AgrrTranslateParser } from '../core/i18n/agrr-translate.parser';
import { UndoToastService } from './undo-toast.service';

describe('UndoToastService', () => {
  let service: UndoToastService;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [
        TranslateModule.forRoot({
          parser: provideTranslateParser(AgrrTranslateParser)
        })
      ],
      providers: [UndoToastService]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('in', {
      plans: {
        undo: {
          toast: '{{name}} हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।'
        }
      }
    });
    translate.use('in');

    service = TestBed.inject(UndoToastService);
  });

  it('interpolates bare undo toast keys using resource label from API', () => {
    service.showWithUndo(
      'plans.undo.toast',
      '/undo_deletion?undo_token=t',
      't',
      undefined,
      'My Plan'
    );

    expect(service.state().message).toBe(
      'My Plan हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।'
    );
  });
});
