import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { SendContactMessageUseCase } from './send-contact-message.usecase';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';
import { ContactGateway } from './contact-gateway';
import { SendContactMessageInputDto } from './send-contact-message.dtos';
import { ContactMessageRecord } from '../../domain/contact/contact-message.model';

describe('SendContactMessageUseCase', () => {
  const baseDto: SendContactMessageInputDto = {
    name: 'contact',
    email: 'a@b.com',
    subject: 'Greetings',
    message: 'hello',
    source: 'landing-page',
    captcha_token: 'tok'
  };

  it('forwards gateway response on success', () => {
    const record: ContactMessageRecord = {
      id: 1,
      status: 'queued'
    };
    const postMessage = vi.fn(() => of(record));
    const gateway: ContactGateway = { postMessage };
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const outputPort: SendContactMessageOutputPort = { onSuccess, onError };

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(baseDto, outputPort);

    expect(postMessage).toHaveBeenCalledWith(baseDto);
    expect(onSuccess).toHaveBeenCalledWith({
      id: record.id,
      status: record.status
    });
    expect(onError).not.toHaveBeenCalled();
  });

  it('maps validation error responses to translation keys', () => {
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(() => ({
          status: 422,
          error: {
            errors: ['Email is invalid'],
            field_errors: { email: ['is invalid'], message: ["can't be blank"] }
          }
        }))
    };
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const outputPort: SendContactMessageOutputPort = { onSuccess, onError };

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(baseDto, outputPort);

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.validation_failed' });
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('maps captcha_failed by error_code', () => {
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(() => ({
          status: 422,
          error: {
            errors: ['Turnstile failure: invalid-input-response'],
            error_code: 'captcha_failed'
          }
        }))
    };
    const onError = vi.fn();
    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(baseDto, { onSuccess: vi.fn(), onError });

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.captcha_failed' });
  });

  it('maps captcha_unavailable by error_code', () => {
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(() => ({
          status: 503,
          error: {
            errors: ['CAPTCHA is not configured'],
            error_code: 'captcha_unavailable'
          }
        }))
    };
    const onError = vi.fn();
    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(baseDto, { onSuccess: vi.fn(), onError });

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.captcha_unavailable' });
  });

  it('maps 429 to send_failed', () => {
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(() => ({
          status: 429,
          error: { errors: ['rate_limit'] }
        }))
    };
    const onError = vi.fn();
    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(baseDto, { onSuccess: vi.fn(), onError });

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.send_failed' });
  });
});
