import { Injectable, inject } from '@angular/core';
import { Observable, map, tap } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { AuthService } from '../../services/auth.service';
import { ApiKeyService } from '../../services/api-key.service';
import {
  API_KEY_GATEWAY,
  ApiKeyGateway,
  ApiKeyResponse
} from '../../usecase/api-keys/api-key-gateway';

@Injectable()
export class ApiKeyApiGateway implements ApiKeyGateway {
  private readonly apiClient = inject(ApiClientService);
  private readonly authService = inject(AuthService);
  private readonly apiKeyService = inject(ApiKeyService);

  getCurrentKey(): Observable<string | null> {
    return this.authService.loadCurrentUser().pipe(
      map(() => {
        const user = this.authService.user();
        const fromUser = user && 'api_key' in user ? (user as { api_key?: string }).api_key : undefined;
        return fromUser ?? this.apiKeyService.getApiKey() ?? null;
      })
    );
  }

  generateKey(): Observable<ApiKeyResponse> {
    return this.apiClient
      .post<ApiKeyResponse>('/api/v1/api_keys/generate', {})
      .pipe(
        tap((res) => {
          if (res.success) this.apiKeyService.setApiKey(res.api_key);
        })
      );
  }

  regenerateKey(): Observable<ApiKeyResponse> {
    return this.apiClient
      .post<ApiKeyResponse>('/api/v1/api_keys/regenerate', {})
      .pipe(
        tap((res) => {
          if (res.success) this.apiKeyService.setApiKey(res.api_key);
        })
      );
  }
}
