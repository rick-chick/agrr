import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AccountManagementService } from '../../../services/account-management.service';
import { ApiService } from '../../../services/api.service';
import { FlashMessageService } from '../../../services/flash-message.service';
import { AccountComponent } from './account.component';

describe('AccountComponent', () => {
  let fixture: ComponentFixture<AccountComponent>;
  let component: AccountComponent;
  let accountService: {
    exportData: ReturnType<typeof vi.fn>;
    deleteAccount: ReturnType<typeof vi.fn>;
  };
  let api: { getCurrentUser: ReturnType<typeof vi.fn> };
  let flash: { show: ReturnType<typeof vi.fn> };
  let router: { navigate: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    accountService = {
      exportData: vi.fn(() => of({ user: { id: 1 } })),
      deleteAccount: vi.fn(() => of(void 0))
    };
    api = {
      getCurrentUser: vi.fn(() => of({ user: { email: 'user@example.com' } }))
    };
    flash = { show: vi.fn() };
    router = { navigate: vi.fn().mockResolvedValue(true) };
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    await TestBed.configureTestingModule({
      imports: [AccountComponent, TranslateModule.forRoot()],
      providers: [
        { provide: AccountManagementService, useValue: accountService },
        { provide: ApiService, useValue: api },
        { provide: FlashMessageService, useValue: flash },
        { provide: Router, useValue: router }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      account: {
        title: 'Account',
        description: 'Manage your account.',
        export: {
          heading: 'Export',
          description: 'Download your data.',
          action: 'Export data',
          success: 'Exported.',
          failure: 'Export failed.'
        },
        delete: {
          heading: 'Delete account',
          description: 'Permanently delete your account.',
          email_label: 'Confirm email',
          confirm_checkbox: 'I understand this cannot be undone.',
          action: 'Delete account',
          confirm_dialog: 'Are you sure you want to delete your account? This cannot be undone.',
          success: 'Account deleted.',
          failure: 'Delete failed.'
        }
      },
      common: { cancel: 'Cancel', confirm: 'Confirm' }
    });
    translate.use('en');

    fixture = TestBed.createComponent(AccountComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('opens delete confirm dialog instead of window.confirm', () => {
    component.confirmChecked = true;

    component.deleteAccount();
    fixture.detectChanges();

    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('.account__delete-confirm')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain(
      'Are you sure you want to delete your account? This cannot be undone.'
    );
    expect(accountService.deleteAccount).not.toHaveBeenCalled();
  });

  it('does not open dialog when confirmation checkbox is unchecked', () => {
    component.confirmChecked = false;

    component.deleteAccount();

    expect(HTMLDialogElement.prototype.showModal).not.toHaveBeenCalled();
    expect(accountService.deleteAccount).not.toHaveBeenCalled();
  });

  it('cancels delete from confirm dialog', () => {
    component.confirmChecked = true;
    component.openDeleteConfirmDialog();
    fixture.detectChanges();

    component.cancelDeleteConfirmDialog();

    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
    expect(accountService.deleteAccount).not.toHaveBeenCalled();
  });

  it('deletes account when confirm dialog is accepted', async () => {
    component.confirmChecked = true;
    component.openDeleteConfirmDialog();
    fixture.detectChanges();

    component.confirmDeleteAccount();
    await fixture.whenStable();

    expect(accountService.deleteAccount).toHaveBeenCalledWith(true, undefined);
    expect(router.navigate).toHaveBeenCalledWith(['/login']);
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('shows export failure message when export fails', async () => {
    accountService.exportData.mockReturnValue(throwError(() => new Error('fail')));

    component.exportData();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(component.errorMessage).toBe('Export failed.');
  });
});
