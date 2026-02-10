import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { SendContactMessageUseCase } from './send-contact-message.usecase';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';
import { ContactGateway } from './contact-gateway';
import { SendContactMessageInputDto } from './send-contact-message.dtos';
import { ContactMessageRecord } from '../../domain/contact/contact-message.model';

describe('SendContactMessageUseCase', () => {
  it('forwards gateway response when status is sent', () => {
    const dto: SendContactMessageInputDto = {
      name: 'contact',
      email: 'a@b.com',
      subject: 'Greetings',
      message: 'hello',
      source: 'landing-page'
    };
    const record: ContactMessageRecord = {
      id: 1,
      name: dto.name,
      email: dto.email,
      subject: dto.subject,
      message: dto.message,
      source: dto.source,
      status: 'sent',
      created_at: '2026-02-10T00:00:00Z',
      sent_at: '2026-02-10T00:00:01Z'
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
      status: record.status,
      created_at: record.created_at,
      sent_at: record.sent_at
    });
    expect(onError).not.toHaveBeenCalled();
  });

  it('calls onError when gateway returns a failed status', () => {
    const dto: SendContactMessageInputDto = {
      name: 'contact',
      email: 'fail@example.com',
      subject: 'Oops',
      message: 'issue',
      source: null
    };
    const record: ContactMessageRecord = {
      id: 2,
      name: dto.name,
      email: dto.email,
      subject: dto.subject,
      message: dto.message,
      source: null,
      status: 'failed',
      created_at: '2026-02-10T00:00:00Z',
      sent_at: null
    };
    const gateway: ContactGateway = { postMessage: () => of(record) };
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const outputPort: SendContactMessageOutputPort = { onSuccess, onError };

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, outputPort);

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.send_failed' });
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('maps validation error responses to translation keys', () => {
    const dto: SendContactMessageInputDto = {
      name: null,
      email: 'invalid',
      subject: null,
      message: '',
      source: null
    };
    const gateway: ContactGateway = {
      postMessage: () =>
        throwError(() => ({
          status: 422,
          error: { field_errors: { email: ['is invalid'], message: ["can't be blank"] } }
        }))
    };
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const outputPort: SendContactMessageOutputPort = { onSuccess, onError };

    const uc = new SendContactMessageUseCase(gateway);
    uc.execute(dto, outputPort);

    expect(onError).toHaveBeenCalledWith({ message: 'contact_form.errors.validation_failed' });
    expect(onSuccess).not.toHaveBeenCalled();
  });
});

