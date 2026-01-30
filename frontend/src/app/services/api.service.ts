import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from './api-client.service';

export interface CurrentUser {
  id: number;
  name: string | null;
  email: string | null;
  avatar_url: string | null;
  admin: boolean;
  api_key?: string | null;
}

export interface MeResponse {
  user: CurrentUser;
}

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private readonly apiClient: ApiClientService) {}

  getCurrentUser(): Observable<MeResponse> {
    return this.apiClient.get<MeResponse>('/api/v1/auth/me');
  }

  logout(): Observable<{ success: boolean }> {
    return this.apiClient.delete<{ success: boolean }>('/api/v1/auth/logout');
  }
}
