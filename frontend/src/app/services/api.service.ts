import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { getApiBaseUrl } from '../core/api-base-url';

type RequestOptions = {
  headers?: HttpHeaders | { [header: string]: string | string[] };
  params?: HttpParams | { [param: string]: string | string[] };
};

export interface CurrentUser {
  id: number;
  name: string | null;
  email: string | null;
  avatar_url: string | null;
  admin: boolean;
  api_key?: string | null;
  region?: string | null;
}

export interface MeResponse {
  user: CurrentUser;
}

/**
 * アプリ全体の JSON API クライアント（旧 ApiClientService + 認証ヘルパーを統合、T-052）。
 */
@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = getApiBaseUrl();

  getCurrentUser(): Observable<MeResponse> {
    return this.get<MeResponse>('/api/v1/auth/me');
  }

  logout(): Observable<{ success: boolean }> {
    return this.delete<{ success: boolean }>('/api/v1/auth/logout');
  }

  get<T>(path: string, options: RequestOptions = {}): Observable<T> {
    let headers =
      options.headers instanceof HttpHeaders ? options.headers : new HttpHeaders(options.headers);

    headers = headers.set('Accept', 'application/json');

    return this.http.get<T>(`${this.baseUrl}${path}`, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  post<T>(path: string, body: unknown, options: RequestOptions = {}): Observable<T> {
    let headers =
      options.headers instanceof HttpHeaders ? options.headers : new HttpHeaders(options.headers);

    headers = headers.set('Accept', 'application/json');

    return this.http.post<T>(`${this.baseUrl}${path}`, body, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  patch<T>(path: string, body: unknown, options: RequestOptions = {}): Observable<T> {
    let headers =
      options.headers instanceof HttpHeaders ? options.headers : new HttpHeaders(options.headers);

    headers = headers.set('Accept', 'application/json');

    return this.http.patch<T>(`${this.baseUrl}${path}`, body, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  put<T>(path: string, body: unknown, options: RequestOptions = {}): Observable<T> {
    let headers =
      options.headers instanceof HttpHeaders ? options.headers : new HttpHeaders(options.headers);

    headers = headers.set('Accept', 'application/json');

    return this.http.put<T>(`${this.baseUrl}${path}`, body, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  putBytes(path: string, body: Blob, contentType: string): Observable<void> {
    return this.http.put<void>(`${this.baseUrl}${path}`, body, {
      headers: new HttpHeaders({
        'Content-Type': contentType
      }),
      withCredentials: true,
      responseType: 'text' as 'json'
    });
  }

  delete<T>(path: string, options: RequestOptions = {}): Observable<T> {
    let headers =
      options.headers instanceof HttpHeaders ? options.headers : new HttpHeaders(options.headers);

    headers = headers.set('Accept', 'application/json');

    return this.http.delete<T>(`${this.baseUrl}${path}`, {
      ...options,
      headers,
      withCredentials: true
    });
  }
}
