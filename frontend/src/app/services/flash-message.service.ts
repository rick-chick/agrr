import { Injectable, signal } from '@angular/core';

export type FlashMessage = {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  text: string;
};

@Injectable({ providedIn: 'root' })
export class FlashMessageService {
  private readonly messagesSignal = signal<FlashMessage[]>([]);

  messages() {
    return this.messagesSignal();
  }

  show(message: Omit<FlashMessage, 'id'>) {
    const id = crypto.randomUUID();
    this.messagesSignal.update((messages) => [...messages, { id, ...message }]);
  }

  remove(id: string) {
    this.messagesSignal.update((messages) => messages.filter((message) => message.id !== id));
  }

  clear() {
    this.messagesSignal.set([]);
  }
}
