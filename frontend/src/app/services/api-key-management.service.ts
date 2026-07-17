import { Injectable, inject } from '@angular/core';
import { Observable, map, tap } from 'rxjs';
import { ApiService } from './api.service';
import { ApiKeyService } from './api-key.service';
import { AuthService } from './auth.service';

export const API_DOCS_URL =
  'https://github.com/rick-chick/agrr/blob/master/docs/api/getting-started.md';

type ApiKeyRotateResponse = {
  api_key: string;
};

@Injectable({ providedIn: 'root' })
export class ApiKeyManagementService {
  private readonly api = inject(ApiService);
  private readonly authService = inject(AuthService);
  private readonly apiKeyService = inject(ApiKeyService);

  getCurrentKey(): Observable<string | null> {
    return this.authService.loadCurrentUser().pipe(
      map(() => {
        const user = this.authService.user();
        return user?.api_key ?? this.apiKeyService.getApiKey() ?? null;
      })
    );
  }

  generateKey(): Observable<string> {
    return this.rotateKey('/api/v1/api_keys/generate');
  }

  regenerateKey(): Observable<string> {
    return this.rotateKey('/api/v1/api_keys/regenerate');
  }

  private rotateKey(path: string): Observable<string> {
    return this.api.post<ApiKeyRotateResponse>(path, {}).pipe(
      map((response) => response.api_key),
      tap((apiKey) => this.apiKeyService.setApiKey(apiKey))
    );
  }
}
