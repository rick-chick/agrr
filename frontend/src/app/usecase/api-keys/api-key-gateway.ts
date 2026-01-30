import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';

export interface ApiKeyResponse {
  api_key: string;
  success: boolean;
}

export interface ApiKeyGateway {
  getCurrentKey(): Observable<string | null>;
  generateKey(): Observable<ApiKeyResponse>;
  regenerateKey(): Observable<ApiKeyResponse>;
}

export const API_KEY_GATEWAY = new InjectionToken<ApiKeyGateway>('API_KEY_GATEWAY');
