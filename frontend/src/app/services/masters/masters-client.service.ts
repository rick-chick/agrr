import { Injectable, inject } from '@angular/core';
import { HttpHeaders } from '@angular/common/http';
import { TranslateService } from '@ngx-translate/core';
import { Observable, defer } from 'rxjs';
import { map } from 'rxjs/operators';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { parseDeletionUndoResponse } from '../../domain/shared/parse-deletion-undo-response';
import { ApiService } from '../api.service';

@Injectable({ providedIn: 'root' })
export class MastersClientService {
  private readonly translate = inject(TranslateService);

  constructor(private readonly apiClient: ApiService) {}

  private getHeaders(): HttpHeaders {
    const lang = this.translate.currentLang || this.translate.defaultLang || 'ja';
    return new HttpHeaders({ 'Accept-Language': lang });
  }

  /**
   * Masters API はセッション Cookie で認証する（Web ログイン済み SPA）。
   * API キーは外部クライアント向け — ブラウザからは送信しない。
   */
  get<T>(path: string): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      return this.apiClient.get<T>(`/api/v1/masters${path}`, { headers });
    });
  }

  post<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      return this.apiClient.post<T>(`/api/v1/masters${path}`, body, { headers });
    });
  }

  patch<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      return this.apiClient.patch<T>(`/api/v1/masters${path}`, body, { headers });
    });
  }

  put<T>(path: string, body: unknown): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      return this.apiClient.put<T>(`/api/v1/masters${path}`, body, { headers });
    });
  }

  delete<T>(path: string): Observable<T> {
    return defer(() => {
      const headers = this.getHeaders();
      return this.apiClient.delete<T>(`/api/v1/masters${path}`, { headers });
    });
  }

  /** Masters DELETE with undo (flat or `{ undo: … }` JSON). */
  deleteWithUndo(path: string): Observable<DeletionUndoResponse | undefined> {
    return this.delete<unknown>(path).pipe(map((body) => parseDeletionUndoResponse(body)));
  }
}
