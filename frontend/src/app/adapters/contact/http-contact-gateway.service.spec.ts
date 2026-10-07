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

  it('postMessage maps queued API response to id and status only', async () => {
    const payload: ContactMessagePayload = {
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Hello',
      message: 'This is a message',
      source: 'marketing-page',
      captcha_token: 'tok'
    };

    vi.mocked(apiClient.post).mockReturnValue(of({ id: 7, status: 'queued' }));

    const res = await firstValueFrom(gateway.postMessage(payload));
    expect(res).toStrictEqual({ id: 7, status: 'queued' });
    expect(apiClient.post).toHaveBeenCalledWith('/api/v1/contact_messages', payload);
  });

  it('postMessage sends captcha_token in JSON body', async () => {
    const payload: ContactMessagePayload = {
      email: 'user@example.com',
      message: 'Hello there',
      captcha_token: 'tok'
    };
    vi.mocked(apiClient.post).mockReturnValue(of({ id: 2, status: 'queued' }));

    await firstValueFrom(gateway.postMessage(payload));

    const body = apiClient.post.mock.calls[0][1] as Record<string, unknown>;
    expect(body['captcha_token']).toBe('tok');
  });

  it('postMessage forwards error when api fails', async () => {
    const payload = {
      email: 'a@b.com',
      message: 'hi',
      captcha_token: 't'
    } as ContactMessagePayload;
    vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

    await expect(firstValueFrom(gateway.postMessage(payload))).rejects.toThrow('network error');
  });
});
