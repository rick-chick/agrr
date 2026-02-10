import { TestBed } from '@angular/core/testing';
import { ChangeDetectorRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { ContactFormComponent } from './contact-form.component';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import { UndoToastService } from '../../services/undo-toast.service';

const translationMap = new Map<string, string>([
  ['contact_form.validation.message_required', 'メッセージは必須です。'],
  ['contact_form.validation.email_required', 'メールアドレスは必須です。'],
  ['contact_form.success.message', 'メッセージを送信しました。'],
  ['contact_form.success.toast', 'お問い合わせありがとうございます。'],
  ['contact_form.errors.send_failed', '送信に失敗しました。']
]);

const createTranslateServiceMock = () => ({
  instant: vi.fn((key: string) => translationMap.get(key) ?? key)
});

describe('ContactFormComponent', () => {
  let component: ContactFormComponent;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockToast: { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockUseCase = { execute: vi.fn() };
    mockToast = { show: vi.fn() };
    const mockTranslate = createTranslateServiceMock();

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ContactFormComponent,
        { provide: SendContactMessageUseCase, useValue: mockUseCase },
        { provide: UndoToastService, useValue: mockToast },
        { provide: ChangeDetectorRef, useValue: { detectChanges: () => {} } },
        { provide: TranslateService, useValue: mockTranslate }
      ]
    });

    component = TestBed.inject(ContactFormComponent);
  });

  afterEach(() => {
    vi.restoreAllMocks();
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
    expect(call[1]).toBe(component);
  });

  it('does not call useCase when message is empty and sets error', () => {
    component.name = 'Taro';
    component.email = 'taro@example.com';
    component.subject = 'Hello';
    component.message = '';

    component.submit();

    expect(mockUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.error).toContain('必須');
  });
});

