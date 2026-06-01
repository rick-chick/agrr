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

const translationMap = new Map<string, string>([
  ['contact_form.validation.message_required', 'メッセージは必須です。'],
  ['contact_form.validation.email_required', 'メールアドレスは必須です。']
]);

describe('ContactFormComponent', () => {
  let component: ContactFormComponent;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...CONTACT_FORM_PROVIDERS,
        ContactFormComponent,
        { provide: SendContactMessageUseCase, useValue: mockUseCase },
        { provide: ContactFormPresenter, useValue: mockPresenter },
        { provide: ChangeDetectorRef, useValue: { detectChanges: () => {} } },
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

  it('calls useCase.execute with payload when valid', () => {
    component.name = 'Taro';
    component.email = 'taro@example.com';
    component.subject = 'Hello';
    component.message = 'This is a message';

    component.submit();

    expect(mockUseCase.execute).toHaveBeenCalledTimes(1);
    const call = mockUseCase.execute.mock.calls[0];
    const arg = call[0];
    expect(arg.email).toBe('taro@example.com');
    expect(arg.message).toBe('This is a message');
    expect(call[1]).toBe(mockPresenter);
  });

  it('does not call useCase when message is empty and sets a validation message', () => {
    component.name = 'Taro';
    component.email = 'taro@example.com';
    component.subject = 'Hello';
    component.message = '';

    component.submit();

    expect(mockUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.message?.variant).toBe('validation');
    expect(component.control.message?.ariaLive).toBe('assertive');
    expect(component.control.message?.text).toContain('必須');
  });
});
