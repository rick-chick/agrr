import { TestBed } from '@angular/core/testing';
import { ChangeDetectorRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { ContactFormComponent } from './contact-form.component';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import {
  ContactFormPresenter,
  CONTACT_FORM_PROVIDERS
} from '../../usecase/contact/contact-form.providers';
import { CAPTCHA_WIDGET_PORT } from '../../usecase/contact/captcha-widget.port';

const translationMap = new Map<string, string>([
  ['contact_form.validation.message_required', 'メッセージは必須です。'],
  ['contact_form.validation.email_required', 'メールアドレスは必須です。']
]);

describe('ContactFormComponent', () => {
  let component: ContactFormComponent;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn>; onSuccess: ReturnType<typeof vi.fn>; onError: ReturnType<typeof vi.fn> };
  let mockCaptcha: {
    isConfigured: ReturnType<typeof vi.fn>;
    render: ReturnType<typeof vi.fn>;
    reset: ReturnType<typeof vi.fn>;
    remove: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn(), onSuccess: vi.fn(), onError: vi.fn() };
    mockCaptcha = {
      isConfigured: vi.fn(() => true),
      render: vi.fn(),
      reset: vi.fn(),
      remove: vi.fn()
    };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...CONTACT_FORM_PROVIDERS,
        ContactFormComponent,
        { provide: SendContactMessageUseCase, useValue: mockUseCase },
        { provide: ContactFormPresenter, useValue: mockPresenter },
        { provide: CAPTCHA_WIDGET_PORT, useValue: mockCaptcha },
        { provide: ChangeDetectorRef, useValue: { detectChanges: () => {}, markForCheck: () => {} } },
        {
          provide: TranslateService,
          useValue: {
            instant: vi.fn((key: string) => translationMap.get(key) ?? key)
          }
        }
      ]
    });

    component = TestBed.inject(ContactFormComponent);
    component.ngOnInit();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('wires the presenter view on init', () => {
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('calls useCase.execute with captcha_token when valid', () => {
    component.name = 'Taro';
    component.email = 'taro@example.com';
    component.subject = 'Hello';
    component.message = 'This is a message';
    component.captchaToken = 'tok';

    component.submit();

    expect(mockUseCase.execute).toHaveBeenCalledTimes(1);
    const arg = mockUseCase.execute.mock.calls[0][0];
    expect(arg.email).toBe('taro@example.com');
    expect(arg.captcha_token).toBe('tok');
  });

  it('does not call useCase when message is empty and sets a validation message', () => {
    component.name = 'Taro';
    component.email = 'taro@example.com';
    component.subject = 'Hello';
    component.message = '';
    component.captchaToken = 'tok';

    component.submit();

    expect(mockUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.message?.variant).toBe('validation');
  });
});
