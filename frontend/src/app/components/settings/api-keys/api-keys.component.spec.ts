import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { API_DOCS_URL, ApiKeyManagementService } from '../../../services/api-key-management.service';
import { FlashMessageService } from '../../../services/flash-message.service';
import { ApiKeysComponent } from './api-keys.component';

describe('ApiKeysComponent', () => {
  let fixture: ComponentFixture<ApiKeysComponent>;
  let component: ApiKeysComponent;
  let translate: TranslateService;
  let management: {
    getCurrentKey: ReturnType<typeof vi.fn>;
    generateKey: ReturnType<typeof vi.fn>;
    regenerateKey: ReturnType<typeof vi.fn>;
  };
  let flash: { show: ReturnType<typeof vi.fn> };
  let confirmSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(async () => {
    management = {
      getCurrentKey: vi.fn(() => of(null)),
      generateKey: vi.fn(() => of('generated-key')),
      regenerateKey: vi.fn(() => of('regenerated-key'))
    };
    flash = { show: vi.fn() };
    confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

    await TestBed.configureTestingModule({
      imports: [ApiKeysComponent, TranslateModule.forRoot()],
      providers: [
        { provide: ApiKeyManagementService, useValue: management },
        { provide: FlashMessageService, useValue: flash }
      ]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      api_keys: {
        title: 'API Keys',
        description_html: 'Use API keys to access masters CRUD.',
        label: 'API key',
        warning: 'Keep your key safe.',
        copy: { button: 'Copy', success: 'Copied!' },
        actions: {
          generate: 'Generate API key',
          regenerate: 'Regenerate API key',
          regenerate_confirm: 'Regenerating invalidates the current key. Continue?'
        },
        notices: { missing: 'No API key yet.' },
        usage: {
          heading: 'Usage',
          headers: { header: 'Headers', or: 'or' },
          query: { heading: 'Query' },
          reference_button: 'Open API reference',
          endpoints: { heading: 'Endpoints', list_html: '<ul><li>GET /api/v1/masters/crops</li></ul>' }
        },
        flash: {
          generate: { success: 'Generated.', failure: 'Generate failed.' },
          regenerate: { success: 'Regenerated.', failure: 'Regenerate failed.' }
        }
      },
      common: { loading: 'Loading...' }
    });
    translate.use('en');

    fixture = TestBed.createComponent(ApiKeysComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads the current key on init', () => {
    expect(management.getCurrentKey).toHaveBeenCalled();
  });

  it('renders generate action when no key is present', async () => {
    management.getCurrentKey.mockReturnValue(of(null));
    component.ngOnInit();
    fixture.detectChanges();
    await fixture.whenStable();

    const button = fixture.nativeElement.querySelector('button.btn-primary');
    expect(button?.textContent?.trim()).toBe('Generate API key');
  });

  it('generates a key and shows success flash', async () => {
    management.getCurrentKey.mockReturnValue(of(null));
    component.ngOnInit();
    fixture.detectChanges();
    await fixture.whenStable();

    component.generate();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(management.generateKey).toHaveBeenCalled();
    expect(component.apiKey).toBe('generated-key');
    expect(flash.show).toHaveBeenCalledWith({
      type: 'success',
      text: 'api_keys.flash.generate.success'
    });
  });

  it('uses TranslateService for regenerate confirmation', async () => {
    management.getCurrentKey.mockReturnValue(of('existing-key'));
    component.ngOnInit();
    fixture.detectChanges();
    await fixture.whenStable();

    component.regenerate();

    expect(confirmSpy).toHaveBeenCalledWith(
      'Regenerating invalidates the current key. Continue?'
    );
    expect(management.regenerateKey).toHaveBeenCalled();
  });

  it('skips regenerate when confirmation is declined', async () => {
    confirmSpy.mockReturnValue(false);
    management.getCurrentKey.mockReturnValue(of('existing-key'));
    component.ngOnInit();
    fixture.detectChanges();
    await fixture.whenStable();

    component.regenerate();

    expect(management.regenerateKey).not.toHaveBeenCalled();
  });

  it('shows failure flash when generate fails', async () => {
    management.generateKey.mockReturnValue(throwError(() => new Error('fail')));

    component.generate();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(flash.show).toHaveBeenCalledWith({
      type: 'error',
      text: 'api_keys.flash.generate.failure'
    });
  });

  it('exposes API docs URL constant for the reference link', () => {
    expect(component.apiDocsUrl).toBe(API_DOCS_URL);
    expect(component.apiDocsUrl).toContain('getting-started.md');
  });
});
