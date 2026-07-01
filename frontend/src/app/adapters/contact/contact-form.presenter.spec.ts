import { TestBed } from '@angular/core/testing';
import { TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { ContactFormPresenter } from './contact-form.presenter';
import {
  ContactFormView,
  ContactFormViewState
} from '../../components/contact-form/contact-form.view';
import { SendContactMessageSuccessDto } from '../../usecase/contact/send-contact-message.dtos';

const translationMap = new Map<string, string>([
  ['contact_form.success.message', 'お問い合わせを受け付けました。'],
  ['contact_form.success.toast', 'お問い合わせありがとうございます。'],
  ['contact_form.errors.send_failed', '送信に失敗しました。']
]);

describe('ContactFormPresenter', () => {
  let presenter: ContactFormPresenter;
  let lastControl: ContactFormViewState | null;

  const view: ContactFormView = {
    get control(): ContactFormViewState {
      return lastControl ?? { loading: false, sending: false, message: null, pendingToastKey: null };
    },
    set control(value: ContactFormViewState) {
      lastControl = value;
    }
  };

  beforeEach(() => {
    lastControl = { loading: false, sending: true, message: null, pendingToastKey: null };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ContactFormPresenter,
        {
          provide: TranslateService,
          useValue: { instant: vi.fn((key: string) => translationMap.get(key) ?? key) }
        }
      ]
    });

    presenter = TestBed.inject(ContactFormPresenter);
    presenter.setView(view);
  });

  it('publishes a success message with polite live region', () => {
    const successDto: SendContactMessageSuccessDto = {
      id: 42,
      status: 'sent',
      created_at: '2026-01-01T00:00:00.000Z',
      sent_at: '2026-01-01T00:00:10.000Z'
    };

    presenter.onSuccess(successDto);

    expect(lastControl?.sending).toBe(false);
    expect(lastControl?.loading).toBe(false);
    expect(lastControl?.message?.variant).toBe('success');
    expect(lastControl?.message?.ariaLive).toBe('polite');
    expect(lastControl?.message?.text).toBe('お問い合わせを受け付けました。');
    expect(lastControl?.pendingToastKey).toBe('contact_form.success.toast');
  });

  it('shows an error message with assertive live region when sending fails', () => {
    presenter.onError({ message: '' });

    expect(lastControl?.sending).toBe(false);
    expect(lastControl?.loading).toBe(false);
    expect(lastControl?.message?.variant).toBe('error');
    expect(lastControl?.message?.ariaLive).toBe('assertive');
    expect(lastControl?.message?.text).toBe('送信に失敗しました。');
  });
});
