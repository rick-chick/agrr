import { Injectable, signal } from '@angular/core';

export type UndoToastState = {
  visible: boolean;
  message: string;
};

@Injectable({ providedIn: 'root' })
export class UndoToastService {
  private readonly stateSignal = signal<UndoToastState>({
    visible: false,
    message: ''
  });

  state() {
    return this.stateSignal();
  }

  show(message: string) {
    this.stateSignal.set({ visible: true, message });
  }

  hide() {
    this.stateSignal.set({ visible: false, message: '' });
  }
}
