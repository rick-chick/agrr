import {
  Component,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  ElementRef,
  Inject,
  inject,
  OnInit,
  AfterViewInit,
  ViewChild
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
import { FlashMessageService } from '../../services/flash-message.service';
import { applyContactFormViewEffects } from './contact-form-view.effects';
import { CAPTCHA_WIDGET_PORT, CaptchaWidgetPort } from '../../usecase/contact/captcha-widget.port';
import { SendContactMessageOutputPort } from '../../usecase/contact/send-contact-message.output-port';

const initialControl: ContactFormViewState = {
  loading: false,
  sending: false,
  message: null,
  pendingToastKey: null
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

        <div
          class="form-card__field contact-form__captcha"
          #captchaHost
          role="group"
          [attr.aria-label]="'contact_form.captcha.aria_label' | translate"
        ></div>
        <p
          *ngIf="captchaUnavailable"
          class="contact-form__message contact-form__message--error"
          role="alert"
        >
          {{ 'contact_form.errors.captcha_unavailable_ui' | translate }}
        </p>
      </div>

      <div class="form-card__actions">
        <button
          type="submit"
          class="btn btn-primary"
          [disabled]="control.sending || captchaUnavailable || !captchaToken"
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
export class ContactFormComponent implements ContactFormView, OnInit, AfterViewInit {
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly useCase = inject(SendContactMessageUseCase);
  private readonly presenter = inject(ContactFormPresenter);
  private readonly translate = inject(TranslateService);
  private readonly flashMessage = inject(FlashMessageService);

  @ViewChild('captchaHost') captchaHost?: ElementRef<HTMLElement>;

  constructor(@Inject(CAPTCHA_WIDGET_PORT) private readonly captchaWidget: CaptchaWidgetPort) {}

  name: string | null = null;
  email = '';
  subject: string | null = null;
  message = '';
  source: string | null = null;
  captchaToken: string | null = null;
  captchaUnavailable = false;

  private _control: ContactFormViewState = initialControl;
  get control(): ContactFormViewState {
    return this._control;
  }
  set control(value: ContactFormViewState) {
    this._control = applyContactFormViewEffects(value, {
      flash: this.flashMessage
    });
    this.cdr.detectChanges();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.captchaWidget.isConfigured()) {
      this.captchaUnavailable = true;
    }
  }

  ngAfterViewInit(): void {
    if (this.captchaUnavailable || !this.captchaHost) {
      return;
    }
    this.captchaWidget.render(this.captchaHost.nativeElement, {
      onToken: (token) => {
        this.captchaToken = token;
        this.cdr.markForCheck();
      },
      onExpired: () => {
        this.captchaToken = null;
        this.cdr.markForCheck();
      },
      onUnavailable: () => {
        this.captchaUnavailable = true;
        this.captchaToken = null;
        this.cdr.markForCheck();
      }
    });
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

  private resetCaptchaAfterSend(): void {
    this.captchaToken = null;
    this.captchaWidget.reset();
  }

  private buildOutputPort(): SendContactMessageOutputPort {
    return {
      onSuccess: (dto) => {
        this.resetCaptchaAfterSend();
        this.presenter.onSuccess(dto);
      },
      onError: (dto) => {
        this.resetCaptchaAfterSend();
        this.presenter.onError(dto);
      }
    };
  }

  submit(): void {
    const payload: ContactMessagePayload = {
      name: this.name,
      email: this.email,
      subject: this.subject,
      message: this.message,
      source: this.source,
      captcha_token: this.captchaToken
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
    this.useCase.execute(payload, this.buildOutputPort());
  }
}
