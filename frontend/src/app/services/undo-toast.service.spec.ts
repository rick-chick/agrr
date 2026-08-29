import { TestBed } from '@angular/core/testing';
import { NgZone } from '@angular/core';
import { provideTranslateParser, TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import { of } from 'rxjs';

import { AgrrTranslateParser } from '../core/i18n/agrr-translate.parser';
import { ApiService } from './api.service';
import { UndoToastService } from './undo-toast.service';

describe('UndoToastService', () => {
  let service: UndoToastService;
  let translate: TranslateService;
  let apiClient: { post: ReturnType<typeof vi.fn> };
  let ngZoneRun: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    apiClient = { post: vi.fn() };
    ngZoneRun = vi.fn((fn: () => void) => fn());

    await TestBed.configureTestingModule({
      imports: [
        TranslateModule.forRoot({
          parser: provideTranslateParser(AgrrTranslateParser)
        })
      ],
      providers: [
        UndoToastService,
        { provide: ApiService, useValue: apiClient },
        { provide: NgZone, useValue: { run: ngZoneRun } }
      ]
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
      '/undo_deletion',
      't',
      undefined,
      'My Plan'
    );

    expect(service.state().message).toBe(
      'My Plan हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।'
    );
  });

  describe('performUndo', () => {
    it('posts undo_token in body to path without query string', () => {
      const onRestored = vi.fn();
      apiClient.post.mockReturnValue(of({ status: 'restored' }));

      service.showWithUndo('deleted', '/undo_deletion?undo_token=legacy', 'secret-token', onRestored);
      service.performUndo();

      expect(apiClient.post).toHaveBeenCalledWith('/undo_deletion', {
        undo_token: 'secret-token'
      });
      expect(ngZoneRun).toHaveBeenCalled();
      expect(onRestored).toHaveBeenCalled();
      expect(service.state().visible).toBe(false);
    });

    it('does not call onRestored when API returns non-restored status', () => {
      const onRestored = vi.fn();
      apiClient.post.mockReturnValue(of({ status: 'expired' }));

      service.showWithUndo('deleted', '/undo_deletion', 'secret-token', onRestored);
      service.performUndo();

      expect(onRestored).not.toHaveBeenCalled();
      expect(service.state().visible).toBe(false);
    });

    it('hides toast when performUndo is called without pending undo', () => {
      service.showWithUndo('deleted', '/undo_deletion', 'secret-token');
      service.hide();
      service.performUndo();

      expect(apiClient.post).not.toHaveBeenCalled();
      expect(service.state().visible).toBe(false);
    });
  });
});
