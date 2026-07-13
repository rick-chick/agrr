import { Injectable, inject, signal } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { translateServerToastMessage } from '../core/i18n/translate-server-toast-message';

const DEFAULT_SUCCESS_AUTO_DISMISS_MS = 3000;

export type FlashMessage = {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  text: string;
};

export type FlashMessageInput = Omit<FlashMessage, 'id'> & {
  autoDismissMs?: number;
};

@Injectable({ providedIn: 'root' })
export class FlashMessageService {
  private readonly translate = inject(TranslateService);
  private readonly messagesSignal = signal<FlashMessage[]>([]);
  private readonly autoDismissTimers = new Map<string, ReturnType<typeof setTimeout>>();

  messages() {
    return this.messagesSignal();
  }

  show(message: FlashMessageInput) {
    const id = crypto.randomUUID();
    const text = translateServerToastMessage(message.text, (key, params) =>
      this.translate.instant(key, params)
    );
    this.messagesSignal.update((messages) => [...messages, { id, ...message, text }]);

    if (message.type === 'success') {
      const autoDismissMs = message.autoDismissMs ?? DEFAULT_SUCCESS_AUTO_DISMISS_MS;
      this.scheduleAutoDismiss(id, autoDismissMs);
    }
  }

  remove(id: string) {
    this.clearAutoDismissTimer(id);
    this.messagesSignal.update((messages) => messages.filter((message) => message.id !== id));
  }

  clear() {
    for (const id of this.autoDismissTimers.keys()) {
      this.clearAutoDismissTimer(id);
    }
    this.messagesSignal.set([]);
  }

  private scheduleAutoDismiss(id: string, autoDismissMs: number) {
    this.clearAutoDismissTimer(id);
    const timer = setTimeout(() => this.remove(id), autoDismissMs);
    this.autoDismissTimers.set(id, timer);
  }

  private clearAutoDismissTimer(id: string) {
    const timer = this.autoDismissTimers.get(id);
    if (timer !== undefined) {
      clearTimeout(timer);
      this.autoDismissTimers.delete(id);
    }
  }
}
