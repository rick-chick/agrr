import {
  Component,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import {
  SendContactMessageOutputPort,
  SEND_CONTACT_MESSAGE_OUTPUT_PORT
} from '../../usecase/contact/send-contact-message.output-port';
import { CONTACT_GATEWAY_PROVIDER } from '../../adapters/contact/http-contact-gateway.service';
import { ContactFormView, ContactFormViewState } from './contact-form.view';
import {
  ContactMessagePayload,
  validatePayload,
  isValidationFailure
} from '../../domain/contact/contact-message.model';
import { UndoToastService } from '../../services/undo-toast.service';

const initialControl: ContactFormViewState = {
  loading: false,
  sending: false,
  error: null,
  success: null
};

@Component({
  selector: 'app-contact-form',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Default,
  imports: [CommonModule, FormsModule, TranslateModule],
  providers: [
    SendContactMessageUseCase,
    CONTACT_GATEWAY_PROVIDER,
    { provide: SEND_CONTACT_MESSAGE_OUTPUT_PORT, useExisting: ContactFormComponent }
  ],
  template: `
    <form (ngSubmit)="submit()" class="contact-form">
      <div>
        <label for="name">{{ 'contact_form.name' | translate }}</label>
        <input id="name" name="name" [(ngModel)]="name" maxlength="255" />
      </div>

      <div>
        <label for="email">{{ 'contact_form.email' | translate }}</label>
        <input id="email" name="email" [(ngModel)]="email" type="email" required />
      </div>

      <div>
        <label for="subject">{{ 'contact_form.subject' | translate }}</label>
        <input id="subject" name="subject" [(ngModel)]="subject" maxlength="255" />
      </div>

      <div>
        <label for="message">{{ 'contact_form.message' | translate }}</label>
        <textarea id="message" name="message" [(ngModel)]="message" required maxlength="5000"></textarea>
      </div>

      <div class="form-actions">
        <button type="submit" [disabled]="control.sending">{{ control.sending ? ('common.sending' | translate) : ('contact_form.submit' | translate) }}</button>
      </div>

      <div *ngIf="control.loading" class="loading">{{ 'common.loading' | translate }}</div>
      <div *ngIf="control.error" class="error">{{ control.error }}</div>
      <div *ngIf="control.success" class="success">{{ control.success }}</div>
    </form>
  `,
  styles: [
    `
      .contact-form {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .form-actions {
        margin-top: 8px;
      }
      .loading {
        color: #666;
      }
      .error {
        color: #b00020;
      }
      .success {
        color: #0a0;
      }
    `
  ]
})
export class ContactFormComponent implements ContactFormView, SendContactMessageOutputPort {
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly useCase = inject(SendContactMessageUseCase);
  private readonly toast = inject(UndoToastService);
  private readonly translate = inject(TranslateService);

  name: string | null = null;
  email = '';
  subject: string | null = null;
  message = '';
  source: string | null = null;

  private _control: ContactFormViewState = initialControl;
  get control(): ContactFormViewState {
    return this._control;
  }
  set control(value: ContactFormViewState) {
    this._control = value;
    this.cdr.detectChanges();
  }

  // UseCase output port callbacks
  onSuccess(dto: any): void {
    this.control = {
      ...this.control,
      sending: false,
      loading: false,
      error: null,
      success: this.translate.instant('contact_form.success.message')
    };
    this.toast.show(this.translate.instant('contact_form.success.toast'));
  }

  onError(dto: { message: string }): void {
    const messageKey = dto.message?.trim() ? dto.message : 'contact_form.errors.send_failed';
    this.control = {
      ...this.control,
      sending: false,
      loading: false,
      error: this.translate.instant(messageKey),
      success: null
    };
  }

  submit(): void {
    // Build payload and perform basic client-side validation using domain helpers
    const payload: ContactMessagePayload = {
      name: this.name,
      email: this.email,
      subject: this.subject,
      message: this.message,
      source: this.source
    };

    const validation = validatePayload(payload);
    if (isValidationFailure(validation)) {
      this.control = {
        ...this.control,
        error: this.translate.instant(validation.message),
        success: null
      };
      return;
    }

    this.control = { ...this.control, sending: true, loading: true, error: null, success: null };
    this.useCase.execute(payload, this);
  }
}

