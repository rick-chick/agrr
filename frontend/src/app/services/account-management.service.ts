import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

export interface UserDataExport {
  exported_at: string;
  user: {
    id: number;
    email: string | null;
    name: string | null;
    created_at: string | null;
  };
  farms: unknown[];
  crops: unknown[];
  cultivation_plans: unknown[];
}

@Injectable({ providedIn: 'root' })
export class AccountManagementService {
  private readonly api = inject(ApiService);

  exportData(): Observable<UserDataExport> {
    return this.api.get<UserDataExport>('/api/v1/account/export');
  }

  deleteAccount(confirm: boolean, emailConfirm?: string): Observable<{ success: boolean }> {
    const body: { confirm: boolean; email_confirm?: string } = { confirm };
    if (emailConfirm) {
      body.email_confirm = emailConfirm;
    }
    return this.api.deleteWithBody<{ success: boolean }>('/api/v1/account', body);
  }
}
