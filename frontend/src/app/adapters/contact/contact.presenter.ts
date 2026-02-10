import { Injectable } from '@angular/core';
import { SendContactMessageOutputPort } from '../../usecase/contact/send-contact-message.output-port';
import { SendContactMessageSuccessDto } from '../../usecase/contact/send-contact-message.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { ContactFormView } from '../../components/pages/contact/contact-form.view';

@Injectable()
export class ContactPresenter implements SendContactMessageOutputPort {
  private view: ContactFormView | null = null;

  setView(view: ContactFormView): void {
    this.view = view;
  }

  onSuccess(dto: SendContactMessageSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      sending: false,
      error: null,
      success: `送信に成功しました (id: ${dto.id})`
    };
    console.log('✅ [ContactPresenter] message sent', dto);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      sending: false,
      error: dto.message,
      success: null
    };
    console.error('❌ [ContactPresenter] send failed:', dto.message);
  }
}

