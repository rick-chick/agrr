import { Injectable } from '@angular/core';
import { HttpHeaders } from '@angular/common/http';
import { Observable, defer } from 'rxjs';
import { ApiClientService } from '../api-client.service';
import { ApiKeyService } from '../api-key.service';

@Injectable({ providedIn: 'root' })
export class MastersClientService {
  constructor(
    private readonly apiClient: ApiClientService,
    private readonly apiKeyService: ApiKeyService
  ) {}

  private getHeaders(): HttpHeaders {
    const apiKey = this.apiKeyService.getApiKey();
    if (apiKey) {
      return new HttpHeaders({ 'X-API-Key': apiKey });
    }
    return new HttpHeaders();
  }

  /**
   * Masters API は APIキー または セッション認証 をサポート。
   * APIキーがなくても、Webログイン済みならセッションCookieで認証される。
   */
  get<T>(path: string): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.get<T>(`/api/v1/masters${path}`, options);
    });
  }

  post<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.post<T>(`/api/v1/masters${path}`, body, options);
    });
  }

  patch<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.patch<T>(`/api/v1/masters${path}`, body, options);
    });
  }

  delete<T>(path: string): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.delete<T>(`/api/v1/masters${path}`, options);
    });
  }
}
