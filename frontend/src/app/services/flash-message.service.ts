import { Injectable, inject, signal } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { translateServerToastMessage } from '../core/i18n/translate-server-toast-message';

export type FlashMessage = {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  text: string;
};

@Injectable({ providedIn: 'root' })
export class FlashMessageService {
  private readonly translate = inject(TranslateService);
  private readonly messagesSignal = signal<FlashMessage[]>([]);

  messages() {
    return this.messagesSignal();
  }

  show(message: Omit<FlashMessage, 'id'>) {
    const id = crypto.randomUUID();
    const text = translateServerToastMessage(message.text, (key, params) =>
      this.translate.instant(key, params)
    );
    this.messagesSignal.update((messages) => [...messages, { id, ...message, text }]);
  }

  remove(id: string) {
    this.messagesSignal.update((messages) => messages.filter((message) => message.id !== id));
  }

  clear() {
    this.messagesSignal.set([]);
  }
}
