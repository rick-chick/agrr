import { Injectable, inject } from '@angular/core';
import { ApiClientService } from './api-client.service';
import { Observable, tap } from 'rxjs';

const STORAGE_KEY = 'agrr_api_key';

@Injectable({ providedIn: 'root' })
export class ApiKeyService {
  private apiClient = inject(ApiClientService);

  getApiKey(): string | null {
    return localStorage.getItem(STORAGE_KEY);
  }

  setApiKey(key: string) {
    localStorage.setItem(STORAGE_KEY, key);
  }

  clearApiKey() {
    localStorage.removeItem(STORAGE_KEY);
  }

  generateApiKey(): Observable<{ api_key: string, success: boolean }> {
    return this.apiClient.post<{ api_key: string, success: boolean }>('/api/v1/api_keys/generate', {}).pipe(
      tap(res => {
        if (res.success) this.setApiKey(res.api_key);
      })
    );
  }

  regenerateApiKey(): Observable<{ api_key: string, success: boolean }> {
    return this.apiClient.post<{ api_key: string, success: boolean }>('/api/v1/api_keys/regenerate', {}).pipe(
      tap(res => {
        if (res.success) this.setApiKey(res.api_key);
      })
    );
  }
}
