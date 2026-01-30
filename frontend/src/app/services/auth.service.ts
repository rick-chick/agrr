import { Injectable, signal, inject } from '@angular/core';
import { catchError, map, of, tap, switchMap, Observable } from 'rxjs';
import { ApiService, CurrentUser } from './api.service';
import { ApiKeyService } from './api-key.service';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly userSignal = signal<CurrentUser | null>(null);
  private readonly loadingSignal = signal(false);
  private loaded = false;

  private readonly api = inject(ApiService);
  private readonly apiKeyService = inject(ApiKeyService);

  user() {
    return this.userSignal();
  }

  loading() {
    return this.loadingSignal();
  }

  loadCurrentUser(): Observable<CurrentUser | null> {
    if (this.loaded) {
      return of(this.userSignal());
    }

    this.loadingSignal.set(true);
    return this.api.getCurrentUser().pipe(
      map((response) => response.user),
      tap((user) => {
        if (user.api_key) {
          this.apiKeyService.setApiKey(user.api_key);
        }
        this.userSignal.set(user);
        this.loaded = true;
        this.loadingSignal.set(false);
      }),
      catchError(() => {
        this.userSignal.set(null);
        this.loaded = true;
        this.loadingSignal.set(false);
        return of(null);
      })
    );
  }

  /**
   * APIキーが確実に利用可能であることを保証してから実行する
   */
  ensureApiKey<T>(obs$: Observable<T>): Observable<T> {
    return this.loadCurrentUser().pipe(
      switchMap(() => obs$)
    );
  }

  logout() {
    return this.api.logout().pipe(
      tap(() => {
        this.apiKeyService.clearApiKey();
        this.userSignal.set(null);
      })
    );
  }
}
