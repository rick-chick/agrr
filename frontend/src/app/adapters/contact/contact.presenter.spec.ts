import { describe, it, expect, beforeEach } from 'vitest';
import { ContactPresenter } from './contact.presenter';
import { ContactFormView, ContactFormViewState } from '../../components/pages/contact/contact-form.view';
import { SendContactMessageSuccessDto } from '../../usecase/contact/send-contact-message.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

describe('ContactPresenter', () => {
  let presenter: ContactPresenter;
  let view: ContactFormView;
  let lastControl: ContactFormViewState | null;

  beforeEach(() => {
    presenter = new ContactPresenter();
    lastControl = null;
    view = {
      get control(): ContactFormViewState {
        return lastControl ?? { loading: true, sending: false, error: null, success: null };
      },
      set control(value: ContactFormViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('updates view.control on onSuccess(dto)', () => {
    const dto: SendContactMessageSuccessDto = {
      id: 123,
      status: 'sent',
      created_at: '2026-02-10T00:00:00Z',
      sent_at: '2026-02-10T00:00:01Z'
    };

    presenter.onSuccess(dto);

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.sending).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.success).toContain('123');
  });

  it('updates view.control on onError(dto)', () => {
    const initial: ContactFormViewState = { loading: false, sending: true, error: null, success: null };
    lastControl = initial;
    const dto: ErrorDto = { message: 'Validation failed: message is required' };

    presenter.onError(dto);

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.sending).toBe(false);
    expect(lastControl!.error).toBe('Validation failed: message is required');
    expect(lastControl!.success).toBeNull();
  });

  it('throws if view not set', () => {
    const p = new ContactPresenter();
    const dto: ErrorDto = { message: 'err' };
    expect(() => p.onError(dto)).toThrow('Presenter: view not set');
    const successDto: SendContactMessageSuccessDto = { id: 1, status: 'sent', created_at: '', sent_at: null };
    expect(() => p.onSuccess(successDto)).toThrow('Presenter: view not set');
  });
});

