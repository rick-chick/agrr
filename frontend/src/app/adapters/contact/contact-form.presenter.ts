import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  ContactFormMessage,
  ContactFormMessageLiveRegion,
  ContactFormMessageVariant,
  ContactFormView
} from '../../components/contact-form/contact-form.view';
import { SendContactMessageOutputPort } from '../../usecase/contact/send-contact-message.output-port';
import { SendContactMessageSuccessDto } from '../../usecase/contact/send-contact-message.dtos';

@Injectable()
export class ContactFormPresenter implements SendContactMessageOutputPort {
  private readonly translate = inject(TranslateService);
  private readonly messageLiveRegion: Record<ContactFormMessageVariant, ContactFormMessageLiveRegion> = {
    success: 'polite',
    error: 'assertive',
    validation: 'assertive'
  };

  private view: ContactFormView | null = null;

  setView(view: ContactFormView): void {
    this.view = view;
  }

  onSuccess(_dto: SendContactMessageSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      sending: false,
      loading: false,
      message: this.createMessage('success', 'contact_form.success.message'),
      pendingToastKey: 'contact_form.success.toast'
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const messageKey = dto.message?.trim() ? dto.message : 'contact_form.errors.send_failed';
    this.view.control = {
      ...this.view.control,
      sending: false,
      loading: false,
      message: this.createMessage('error', messageKey)
    };
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
}
