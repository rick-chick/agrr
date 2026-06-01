import {
  Component,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  inject,
  OnInit
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { SendContactMessageUseCase } from '../../usecase/contact/send-contact-message.usecase';
import {
  CONTACT_FORM_PROVIDERS,
  ContactFormPresenter
} from '../../usecase/contact/contact-form.providers';
import {
  ContactFormView,
  ContactFormViewState,
  ContactFormMessageVariant,
  ContactFormMessage
} from './contact-form.view';
import {
  ContactMessagePayload,
  validatePayload,
  isValidationFailure
} from '../../domain/contact/contact-message.model';

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
  providers: [...CONTACT_FORM_PROVIDERS],
  template: `
    <form class="form-card" (ngSubmit)="submit()" novalidate>
      <div class="form-card__form">
        <label class="form-card__field" for="name">
          <span class="form-card__field-label">
            {{ 'contact_form.name' | translate }}
          </span>
          <input
            id="name"
            name="name"
            autocomplete="name"
            [(ngModel)]="name"
            maxlength="255"
          />
        </label>

        <label class="form-card__field" for="email">
          <span class="form-card__field-label">
            {{ 'contact_form.email' | translate }}
          </span>
          <input
            id="email"
            name="email"
            autocomplete="email"
            [(ngModel)]="email"
            type="email"
            required
          />
        </label>

        <label class="form-card__field" for="subject">
          <span class="form-card__field-label">
            {{ 'contact_form.subject' | translate }}
          </span>
          <input
            id="subject"
            name="subject"
            autocomplete="off"
            [(ngModel)]="subject"
            maxlength="255"
          />
        </label>

        <label class="form-card__field" for="message">
          <span class="form-card__field-label">
            {{ 'contact_form.message' | translate }}
          </span>
          <textarea
            id="message"
            name="message"
            autocomplete="off"
            rows="6"
            [(ngModel)]="message"
            required
            maxlength="5000"
          ></textarea>
        </label>
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
  styleUrls: ['../masters/_master-layout.css', './contact-form.component.css']
})
export class ContactFormComponent implements ContactFormView, OnInit {
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly useCase = inject(SendContactMessageUseCase);
  private readonly presenter = inject(ContactFormPresenter);
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

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  private createMessage(
    variant: ContactFormMessageVariant,
    translationKey: string
  ): ContactFormMessage {
    return {
      text: this.translate.instant(translationKey),
      variant,
      ariaLive: variant === 'success' ? 'polite' : 'assertive'
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
    this.useCase.execute(payload, this.presenter);
  }
}

