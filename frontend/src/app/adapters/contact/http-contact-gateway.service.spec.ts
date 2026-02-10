import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { HttpContactGateway } from './http-contact-gateway.service';
import { ApiClientService } from '../../services/api-client.service';
import {
  ContactMessagePayload,
  ContactMessageRecord
} from '../../domain/contact/contact-message.model';

describe('HttpContactGateway', () => {
  let apiClient: { post: ReturnType<typeof vi.fn> };
  let gateway: HttpContactGateway;

  beforeEach(() => {
    apiClient = { post: vi.fn() };
    gateway = new HttpContactGateway(apiClient as unknown as ApiClientService);
  });

  it('postMessage posts payload with optional source and returns ContactMessageRecord', async () => {
    const payload: ContactMessagePayload = {
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Hello',
      message: 'This is a message',
      source: 'marketing-page'
    };

    const serverResp = {
      id: 1,
      name: payload.name,
      email: payload.email,
      subject: payload.subject,
      message: payload.message,
      source: payload.source,
      status: 'sent',
      created_at: '2026-02-10T00:00:00Z',
      sent_at: '2026-02-10T00:00:00Z'
    } as unknown as ContactMessageRecord;

    vi.mocked(apiClient.post).mockReturnValue(of(serverResp));

    const res = await firstValueFrom(gateway.postMessage(payload));
    expect(res).toEqual(serverResp);
    expect(apiClient.post).toHaveBeenCalledWith('/api/v1/contact_messages', payload);
    expect(res.source).toBe(payload.source);
  });

  it('postMessage includes status and timestamps from the API response', async () => {
    const payload = { email: 'user@example.com', message: 'Hello there' } as ContactMessagePayload;
    const serverResp = {
      id: 2,
      email: payload.email,
      message: payload.message,
      status: 'failed',
      created_at: '2026-02-11T10:11:12Z',
      sent_at: null
    } as ContactMessageRecord;

    vi.mocked(apiClient.post).mockReturnValue(of(serverResp));

    const res = await firstValueFrom(gateway.postMessage(payload));
    expect(res.status).toBe('failed');
    expect(res.created_at).toBe('2026-02-11T10:11:12Z');
    expect(res.sent_at).toBeNull();
  });

  it('postMessage forwards error when api fails', async () => {
    const payload = { email: 'a@b.com', message: 'hi' } as ContactMessagePayload;
    vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

    await expect(firstValueFrom(gateway.postMessage(payload))).rejects.toThrow('network error');
  });
});

