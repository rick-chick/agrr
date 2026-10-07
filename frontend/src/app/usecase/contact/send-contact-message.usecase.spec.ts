import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { SendContactMessageUseCase } from './send-contact-message.usecase';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';
import { ContactGateway } from './contact-gateway';
import { SendContactMessageInputDto } from './send-contact-message.dtos';
import { ContactMessageRecord } from '../../domain/contact/contact-message.model';

describe('SendContactMessageUseCase', () => {
  it('forwards gateway response on success', () => {
    const dto: SendContactMessageInputDto = {
      name: 'contact',
      email: 'a@b.com',
      subject: 'Greetings',
      message: 'hello',
      source: 'landing-page',
      captcha_token: 'tok'
    };
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
    uc.execute(dto, outputPort);

    expect(postMessage).toHaveBeenCalledWith(dto);
    expect(onSuccess).toHaveBeenCalledWith({
      id: record.id,
      status: record.status
    });
    expect(onError).not.toHaveBeenCalled();
  });

  it('maps captcha_failed error_code', () => {
    const dto: SendContactMessageInputDto = {
      email: 'a@b.com',
      message: 'hello',
      captcha_token: 'tok'
    };
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 422,
              error: {
                errors: ['Turnstile failure: invalid-input-response'],
                error_code: 'captcha_failed'
              }
            })
        )
    };
    const onSuccess = vi.fn();
    const onError = vi.fn();

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, { onSuccess, onError });

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.captcha_failed' });
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('maps captcha_unavailable error_code', () => {
    const dto: SendContactMessageInputDto = {
      email: 'a@b.com',
      message: 'hello',
      captcha_token: 'tok'
    };
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 503,
              error: {
                errors: ['CAPTCHA is not configured'],
                error_code: 'captcha_unavailable'
              }
            })
        )
    };
    const onSuccess = vi.fn();
    const onError = vi.fn();

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, { onSuccess, onError });

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.captcha_unavailable' });
  });

  it('maps validation error responses to translation keys', () => {
    const dto: SendContactMessageInputDto = {
      name: null,
      email: 'invalid',
      subject: null,
      message: 'x',
      source: null,
      captcha_token: 'tok'
    };
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 422,
              error: {
                errors: ['Email is invalid'],
                field_errors: { email: ['is invalid'], message: ["can't be blank"] }
              }
            })
        )
    };
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const outputPort: SendContactMessageOutputPort = { onSuccess, onError };

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, outputPort);

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.validation_failed' });
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('maps rate limit to send_failed', () => {
    const dto: SendContactMessageInputDto = {
      email: 'a@b.com',
      message: 'hello',
      captcha_token: 'tok'
    };
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 429,
              error: { errors: ['rate_limit'] }
            })
        )
    };
    const onError = vi.fn();
    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, { onSuccess: vi.fn(), onError });
    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.send_failed' });
  });
});
