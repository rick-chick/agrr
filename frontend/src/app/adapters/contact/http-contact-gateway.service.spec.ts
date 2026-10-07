import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { HttpContactGateway } from './http-contact-gateway.service';
import { ApiService } from '../../services/api.service';
import { ContactMessagePayload } from '../../domain/contact/contact-message.model';

describe('HttpContactGateway', () => {
  let apiClient: { post: ReturnType<typeof vi.fn> };
  let gateway: HttpContactGateway;

  beforeEach(() => {
    apiClient = { post: vi.fn() };
    gateway = new HttpContactGateway(apiClient as unknown as ApiService);
  });

  it('postMessage posts captcha_token and maps queued response', async () => {
    const payload: ContactMessagePayload = {
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Hello',
      message: 'This is a message',
      source: 'marketing-page',
      captcha_token: 'tok'
    };

    vi.mocked(apiClient.post).mockReturnValue(of({ id: 1, status: 'queued' }));

    const res = await firstValueFrom(gateway.postMessage(payload));
    expect(res).toStrictEqual({ id: 1, status: 'queued' });
    expect(apiClient.post).toHaveBeenCalledWith('/api/v1/contact_messages', {
      name: payload.name,
      email: payload.email,
      subject: payload.subject,
      message: payload.message,
      source: payload.source,
      captcha_token: 'tok'
    });
  });

  it('postMessage forwards error when api fails', async () => {
    const payload = {
      email: 'a@b.com',
      message: 'hi',
      captcha_token: 'tok'
    } as ContactMessagePayload;
    vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

    await expect(firstValueFrom(gateway.postMessage(payload))).rejects.toThrow('network error');
  });
});
