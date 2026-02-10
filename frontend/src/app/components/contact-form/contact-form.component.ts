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
import { SendContactMessageSuccessDto } from '../../usecase/contact/send-contact-message.dtos';
import {
  SendContactMessageOutputPort,
  SEND_CONTACT_MESSAGE_OUTPUT_PORT
} from '../../usecase/contact/send-contact-message.output-port';
import { CONTACT_GATEWAY_PROVIDER } from '../../adapters/contact/http-contact-gateway.service';
import {
  ContactFormView,
  ContactFormViewState,
  ContactFormMessageVariant,
  ContactFormMessageLiveRegion,
  ContactFormMessage
} from './contact-form.view';
import {
  ContactMessagePayload,
  validatePayload,
  isValidationFailure
} from '../../domain/contact/contact-message.model';
import { UndoToastService } from '../../services/undo-toast.service';
import { ErrorDto } from '../../domain/shared/error.dto';

const initialControl: ContactFormViewState = {
  loading: false,
  sending: false,
  message: null
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
    <form class="form-card" (ngSubmit)="submit()" novalidate>
      <div class="form-card__form">
        <div class="form-card__field">
          <label for="name">{{ 'contact_form.name' | translate }}</label>
          <input
            id="name"
            name="name"
            autocomplete="name"
            [(ngModel)]="name"
            maxlength="255"
          />
        </div>

        <div class="form-card__field">
          <label for="email">{{ 'contact_form.email' | translate }}</label>
          <input
            id="email"
            name="email"
            autocomplete="email"
            [(ngModel)]="email"
            type="email"
            required
          />
        </div>

        <div class="form-card__field">
          <label for="subject">{{ 'contact_form.subject' | translate }}</label>
          <input
            id="subject"
            name="subject"
            autocomplete="off"
            [(ngModel)]="subject"
            maxlength="255"
          />
        </div>

        <div class="form-card__field">
          <label for="message">{{ 'contact_form.message' | translate }}</label>
          <textarea
            id="message"
            name="message"
            autocomplete="off"
            rows="6"
            [(ngModel)]="message"
            required
            maxlength="5000"
          ></textarea>
        </div>
      </div>

      <div class="form-card__actions">
        <button
          type="submit"
          class="btn btn-primary"
          [disabled]="control.sending"
        >
          {{ control.sending ? ('common.sending' | translate) : ('contact_form.submit' | translate) }}
        </button>
      </div>

      <div *ngIf="control.loading || control.message" class="contact-form__status">
        <p
          *ngIf="control.loading"
          class="contact-form__message contact-form__message--loading"
          role="status"
          aria-live="polite"
        >
          {{ 'common.loading' | translate }}
        </p>
        <p
          *ngIf="control.message"
          class="contact-form__message"
          [class.contact-form__message--success]="control.message.variant === 'success'"
          [class.contact-form__message--error]="control.message.variant !== 'success'"
          role="status"
          [attr.aria-live]="control.message.ariaLive"
          aria-atomic="true"
        >
          {{ control.message.text }}
        </p>
      </div>
    </form>
  `,
  styleUrls: ['./contact-form.component.css']
})
export class ContactFormComponent implements ContactFormView, SendContactMessageOutputPort {
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly useCase = inject(SendContactMessageUseCase);
  private readonly toast = inject(UndoToastService);
  private readonly translate = inject(TranslateService);
  private readonly messageLiveRegion: Record<ContactFormMessageVariant, ContactFormMessageLiveRegion> = {
    success: 'polite',
    error: 'assertive',
    validation: 'assertive'
  };

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

  private createMessage(
    variant: ContactFormMessageVariant,
    translationKey: string
  ): ContactFormMessage {
    return {
      text: this.translate.instant(translationKey),
      variant,
      ariaLive: this.messageLiveRegion[variant]
    };
  }

  // UseCase output port callbacks
  onSuccess(dto: SendContactMessageSuccessDto): void {
    this.control = {
      ...this.control,
      sending: false,
      loading: false,
      message: this.createMessage('success', 'contact_form.success.message')
    };
    this.toast.show(this.translate.instant('contact_form.success.toast'));
  }

  onError(dto: ErrorDto): void {
    const messageKey = dto.message?.trim() ? dto.message : 'contact_form.errors.send_failed';
    this.control = {
      ...this.control,
      sending: false,
      loading: false,
      message: this.createMessage('error', messageKey)
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
        sending: false,
        loading: false,
        message: this.createMessage('validation', validation.message)
      };
      return;
    }

    this.control = {
      ...this.control,
      sending: true,
      loading: true,
      message: null
    };
    this.useCase.execute(payload, this);
  }
}

