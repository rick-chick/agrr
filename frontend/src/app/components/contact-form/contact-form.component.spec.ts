import { TestBed } from '@angular/core/testing';
import { ChangeDetectorRef, ElementRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { ContactFormComponent } from './contact-form.component';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import {
  ContactFormPresenter,
  CONTACT_FORM_PROVIDERS
} from '../../usecase/contact/contact-form.providers';
import { CAPTCHA_WIDGET_PORT, CaptchaWidgetPort } from '../../usecase/contact/captcha-widget.port';
import { FlashMessageService } from '../../services/flash-message.service';

const translationMap = new Map<string, string>([
  ['contact_form.validation.message_required', 'メッセージは必須です。'],
  ['contact_form.validation.email_required', 'メールアドレスは必須です。'],
  ['contact_form.validation.captcha_required', 'セキュリティ確認を完了してください。']
]);

describe('ContactFormComponent', () => {
  let component: ContactFormComponent;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockCaptcha: CaptchaWidgetPort;

  beforeEach(() => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockCaptcha = {
      isConfigured: () => true,
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
        { provide: ChangeDetectorRef, useValue: { detectChanges: () => {} } },
        {
          provide: TranslateService,
          useValue: {
            currentLang: 'ja',
            defaultLang: 'ja',
            instant: vi.fn((key: string) => translationMap.get(key) ?? key)
          }
        },
        { provide: FlashMessageService, useValue: { show: vi.fn() } }
      ]
    });

    component = TestBed.inject(ContactFormComponent);
    component.turnstileHost = new ElementRef(document.createElement('div'));
    component.ngOnInit();
    component.ngAfterViewInit();
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
    component.captchaReady = true;

    component.submit();

    expect(mockUseCase.execute).toHaveBeenCalledTimes(1);
    const arg = mockUseCase.execute.mock.calls[0][0];
    expect(arg.captcha_token).toBe('tok');
    expect(mockUseCase.execute.mock.calls[0][1]).toBe(mockPresenter);
  });

  it('does not call useCase when captcha token is missing', () => {
    component.email = 'taro@example.com';
    component.message = 'hello';
    component.captchaToken = null;

    component.submit();

    expect(mockUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.message?.variant).toBe('validation');
  });

  it('does not call useCase when message is empty', () => {
    component.email = 'taro@example.com';
    component.message = '';
    component.captchaToken = 'tok';

    component.submit();

    expect(mockUseCase.execute).not.toHaveBeenCalled();
  });

  it('resetCaptchaWidget clears token and calls widget reset', () => {
    component.captchaToken = 'tok';
    component.resetCaptchaWidget();
    expect(component.captchaToken).toBeNull();
    expect((mockCaptcha.reset as ReturnType<typeof vi.fn>)).toHaveBeenCalled();
  });
});
