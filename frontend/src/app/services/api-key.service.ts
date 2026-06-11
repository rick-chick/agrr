import { Injectable } from '@angular/core';

const STORAGE_KEY = 'agrr_api_key';

@Injectable({ providedIn: 'root' })
export class ApiKeyService {
  getApiKey(): string | null {
    return localStorage.getItem(STORAGE_KEY);
  }

  setApiKey(key: string) {
    localStorage.setItem(STORAGE_KEY, key);
  }

  clearApiKey() {
    localStorage.removeItem(STORAGE_KEY);
  }
}
