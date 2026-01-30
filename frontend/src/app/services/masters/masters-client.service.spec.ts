import { describe, it, expect, vi, beforeEach } from 'vitest';
import { of, firstValueFrom, tap, map, catchError } from 'rxjs';

// Mock HttpHeaders
class MockHttpHeaders {
  private headers = new Map<string, string>();
  constructor(init?: any) {
    if (init) {
      Object.keys(init).forEach(key => this.headers.set(key, init[key]));
    }
  }
  get(name: string) { return this.headers.get(name); }
  set(name: string, value: string) {
    const newHeaders = new MockHttpHeaders();
    this.headers.forEach((v, k) => newHeaders.headers.set(k, v));
    newHeaders.headers.set(name, value);
    return newHeaders;
  }
}

// Logic from masters-client.service.ts (session auth fallback 対応後)
class MastersClientServiceLogic {
  constructor(private apiClient: any, private apiKeyService: any) {}

  private getHeaders(): any {
    const apiKey = this.apiKeyService.getApiKey();
    if (apiKey) return new MockHttpHeaders({ 'X-API-Key': apiKey });
    return new MockHttpHeaders();
  }

  get(path: string): any {
    const headers = this.getHeaders();
    const options = this.apiKeyService.getApiKey() ? { headers } : {};
    return this.apiClient.get(`/api/v1/masters${path}`, options);
  }
}

describe('MastersClientService Logic Verification', () => {
  let service: MastersClientServiceLogic;
  let apiClient: any;
  let apiKeyService: any;

  beforeEach(() => {
    apiClient = { get: vi.fn().mockReturnValue(of({})) };
    apiKeyService = { getApiKey: vi.fn() };
    service = new MastersClientServiceLogic(apiClient, apiKeyService);
  });

  it('should make request without X-API-Key when API key is missing (session auth fallback)', async () => {
    apiKeyService.getApiKey.mockReturnValue(null);
    await firstValueFrom(service.get('/test'));
    expect(apiClient.get).toHaveBeenCalledWith('/api/v1/masters/test', {});
  });

  it('should include X-API-Key header when API key is present', async () => {
    const mockKey = 'test-api-key';
    apiKeyService.getApiKey.mockReturnValue(mockKey);
    apiClient.get.mockReturnValue(of({}));

    await firstValueFrom(service.get('/test'));

    expect(apiClient.get).toHaveBeenCalledWith(
      '/api/v1/masters/test',
      expect.objectContaining({
        headers: expect.any(Object)
      })
    );
    
    const callArgs = apiClient.get.mock.calls[0];
    const headers = callArgs[1].headers;
    expect(headers.get('X-API-Key')).toBe(mockKey);
  });
});
