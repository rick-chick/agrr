import { ChangeDetectorRef, Component, ElementRef, OnInit, ViewChild, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AccountManagementService } from '../../../services/account-management.service';
import { ApiService } from '../../../services/api.service';
import { FlashMessageService } from '../../../services/flash-message.service';

@Component({
  selector: 'app-account',
  standalone: true,
  imports: [TranslateModule, FormsModule],
  template: `
    <div class="page-content-container">
      <header class="page-header">
        <h1>{{ 'account.title' | translate }}</h1>
      </header>

      <p class="page-description">{{ 'account.description' | translate }}</p>

      <section class="info-box">
        <h2 class="info-box-title">{{ 'account.export.heading' | translate }}</h2>
        <p class="info-box-content">{{ 'account.export.description' | translate }}</p>
        <button type="button" class="btn btn-primary" (click)="exportData()" [disabled]="exporting">
          {{ 'account.export.action' | translate }}
        </button>
      </section>

      <section class="info-box info-box--danger">
        <h2 class="info-box-title">{{ 'account.delete.heading' | translate }}</h2>
        <p class="info-box-content">{{ 'account.delete.description' | translate }}</p>

        @if (userEmail) {
          <div class="form-group">
            <label class="form-group-label" for="email-confirm">{{ 'account.delete.email_label' | translate }}</label>
            <input
              id="email-confirm"
              type="email"
              class="account-input"
              [(ngModel)]="emailConfirm"
              [placeholder]="userEmail"
            />
          </div>
        }

        <label class="confirm-checkbox">
          <input type="checkbox" [(ngModel)]="confirmChecked" />
          <span>{{ 'account.delete.confirm_checkbox' | translate }}</span>
        </label>

        <button
          type="button"
          class="btn btn-danger"
          (click)="deleteAccount()"
          [disabled]="deleting || !confirmChecked"
        >
          {{ 'account.delete.action' | translate }}
        </button>

        @if (errorMessage) {
          <p class="account-error" role="alert">{{ errorMessage }}</p>
        }
      </section>
    </div>

    <dialog
      #deleteConfirmDialog
      class="confirm-dialog account__delete-confirm"
      [attr.aria-labelledby]="'account-delete-confirm-title'"
      [attr.aria-describedby]="'account-delete-confirm-message'"
      (cancel)="cancelDeleteConfirmDialog($event)"
      (click)="onDeleteConfirmDialogBackdropClick($event)"
    >
      <h2 id="account-delete-confirm-title" class="confirm-dialog__title">
        {{ 'account.delete.heading' | translate }}
      </h2>
      <p id="account-delete-confirm-message" class="confirm-dialog__message">
        {{ 'account.delete.confirm_dialog' | translate }}
      </p>
      <div class="confirm-dialog__actions">
        <button type="button" class="btn btn-secondary" (click)="cancelDeleteConfirmDialog()">
          {{ 'common.cancel' | translate }}
        </button>
        <button type="button" class="btn btn-danger" (click)="confirmDeleteAccount()">
          {{ 'account.delete.action' | translate }}
        </button>
      </div>
    </dialog>
  `,
  styleUrls: ['./account.component.css']
})
export class AccountComponent implements OnInit {
  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;

  private readonly accountService = inject(AccountManagementService);
  private readonly api = inject(ApiService);
  private readonly flash = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  exporting = false;
  deleting = false;
  confirmChecked = false;
  emailConfirm = '';
  userEmail: string | null = null;
  errorMessage: string | null = null;

  ngOnInit(): void {
    this.api.getCurrentUser().subscribe({
      next: (me) => {
        this.userEmail = me.user.email;
        this.cdr.markForCheck();
      }
    });
  }

  exportData(): void {
    this.exporting = true;
    this.errorMessage = null;
    this.accountService.exportData().subscribe({
      next: (data) => {
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = `agrr-export-${data.user.id}.json`;
        anchor.click();
        URL.revokeObjectURL(url);
        this.flash.show({ type: 'success', text: 'account.export.success' });
        this.exporting = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.errorMessage = this.translate.instant('account.export.failure');
        this.exporting = false;
        this.cdr.markForCheck();
      }
    });
  }

  deleteAccount(): void {
    if (!this.confirmChecked) {
      return;
    }
    this.openDeleteConfirmDialog();
  }

  openDeleteConfirmDialog(): void {
    this.deleteConfirmDialogRef?.nativeElement?.showModal();
  }

  confirmDeleteAccount(): void {
    this.deleteConfirmDialogRef?.nativeElement?.close();
    this.executeDeleteAccount();
  }

  cancelDeleteConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.deleteConfirmDialogRef?.nativeElement?.close();
  }

  onDeleteConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.deleteConfirmDialogRef?.nativeElement) {
      this.cancelDeleteConfirmDialog();
    }
  }

  private executeDeleteAccount(): void {
    this.deleting = true;
    this.errorMessage = null;
    this.accountService
      .deleteAccount(true, this.emailConfirm || undefined)
      .subscribe({
        next: () => {
          this.flash.show({ type: 'success', text: 'account.delete.success' });
          void this.router.navigate(['/login']);
        },
        error: (err) => {
          const body = err?.error;
          this.errorMessage =
            body?.message || body?.error || this.translate.instant('account.delete.failure');
          this.deleting = false;
          this.cdr.markForCheck();
        }
      });
  }
}
