import { Injectable, inject } from '@angular/core';
import { HttpHeaders } from '@angular/common/http';
import { TranslateService } from '@ngx-translate/core';
import { Observable, defer } from 'rxjs';
import { map } from 'rxjs/operators';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { parseDeletionUndoResponse } from '../../domain/shared/parse-deletion-undo-response';
import { ApiService } from '../api.service';
import { ApiKeyService } from '../api-key.service';

@Injectable({ providedIn: 'root' })
export class MastersClientService {
  private readonly translate = inject(TranslateService);

  constructor(
    private readonly apiClient: ApiService,
    private readonly apiKeyService: ApiKeyService
  ) {}

  private getHeaders(): HttpHeaders {
    const lang = this.translate.currentLang || this.translate.defaultLang || 'ja';
    let headers = new HttpHeaders({ 'Accept-Language': lang });
    const apiKey = this.apiKeyService.getApiKey();
    if (apiKey) {
      headers = headers.set('X-API-Key', apiKey);
    }
    return headers;
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

  put<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.put<T>(`/api/v1/masters${path}`, body, options);
    });
  }

  delete<T>(path: string): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      const options = headers.keys().length > 0 ? { headers } : {};
      return this.apiClient.delete<T>(`/api/v1/masters${path}`, options);
    });
  }

  /** Masters DELETE with undo (flat or `{ undo: … }` JSON). */
  deleteWithUndo(path: string): Observable<DeletionUndoResponse | undefined> {
    return this.delete<unknown>(path).pipe(map((body) => parseDeletionUndoResponse(body)));
  }
}
