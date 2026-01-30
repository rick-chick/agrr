import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { getApiBaseUrl } from '../core/api-base-url';

type RequestOptions = {
  headers?: HttpHeaders | { [header: string]: string | string[] };
  params?: HttpParams | { [param: string]: string | string[] };
};

@Injectable({ providedIn: 'root' })
export class ApiClientService {
  private http = inject(HttpClient);
  private baseUrl = getApiBaseUrl();

  get<T>(path: string, options: RequestOptions = {}): Observable<T> {
    let headers = (options.headers instanceof HttpHeaders) 
      ? options.headers
      : new HttpHeaders(options.headers);
    
    headers = headers.set('Accept', 'application/json');

    return this.http.get<T>(`${this.baseUrl}${path}`, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  post<T>(path: string, body: unknown, options: RequestOptions = {}): Observable<T> {
    let headers = (options.headers instanceof HttpHeaders) 
      ? options.headers
      : new HttpHeaders(options.headers);
    
    headers = headers.set('Accept', 'application/json');

    return this.http.post<T>(`${this.baseUrl}${path}`, body, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  patch<T>(path: string, body: unknown, options: RequestOptions = {}): Observable<T> {
    let headers = (options.headers instanceof HttpHeaders) 
      ? options.headers
      : new HttpHeaders(options.headers);
    
    headers = headers.set('Accept', 'application/json');

    return this.http.patch<T>(`${this.baseUrl}${path}`, body, {
      ...options,
      headers,
      withCredentials: true
    });
  }

  delete<T>(path: string, options: RequestOptions = {}): Observable<T> {
    let headers = (options.headers instanceof HttpHeaders) 
      ? options.headers
      : new HttpHeaders(options.headers);
    
    headers = headers.set('Accept', 'application/json');

    return this.http.delete<T>(`${this.baseUrl}${path}`, {
      ...options,
      headers,
      withCredentials: true
    });
  }
}
