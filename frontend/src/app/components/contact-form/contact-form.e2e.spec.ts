import { TestBed } from '@angular/core/testing';
import { ChangeDetectorRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { ContactFormComponent } from './contact-form.component';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import { UndoToastService } from '../../services/undo-toast.service';
import { vi } from 'vitest';

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

describe('ContactForm E2E (minimal)', () => {
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockToast: { show: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockUseCase = { execute: vi.fn() } as any;
    mockToast = { show: vi.fn() } as any;
    const mockTranslate = createTranslateServiceMock();

    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      providers: [
        ContactFormComponent,
        { provide: SendContactMessageUseCase, useValue: mockUseCase },
        { provide: UndoToastService, useValue: mockToast },
        { provide: ChangeDetectorRef, useValue: { detectChanges: () => {} } },
        { provide: TranslateService, useValue: mockTranslate }
      ]
    }).compileComponents();
  });

  it('fills form and submits (calls usecase)', () => {
    const comp = TestBed.inject(ContactFormComponent);
    comp.name = 'Hanako';
    comp.email = 'hanako@example.com';
    comp.subject = 'Hi';
    comp.message = 'Hello there';

    comp.submit();

    expect(mockUseCase.execute).toHaveBeenCalled();
  });
});

