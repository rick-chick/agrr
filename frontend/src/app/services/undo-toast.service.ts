import { Injectable, inject, signal, NgZone } from '@angular/core';
import { ApiClientService } from './api-client.service';

export type UndoToastState = {
  visible: boolean;
  message: string;
};

type PendingUndo = {
  undoPath: string;
  undoToken: string;
  onRestored?: () => void;
};

@Injectable({ providedIn: 'root' })
export class UndoToastService {
  private readonly apiClient = inject(ApiClientService);
  private readonly ngZone = inject(NgZone);

  private readonly stateSignal = signal<UndoToastState>({
    visible: false,
    message: ''
  });

  private pendingUndo: PendingUndo | null = null;

  state() {
    return this.stateSignal();
  }

  show(message: string) {
    this.stateSignal.set({ visible: true, message });
  }

  /**
   * 削除後のトーストを表示し、Undo実行時に復元APIを呼ぶように登録する。
   * @param message トーストに表示するメッセージ
   * @param undoPath 復元APIのパス（例: /ja/undo_deletion?undo_token=xxx）
   * @param undoToken 復元に必要なトークン
   * @param onRestored 復元成功時に呼ぶコールバック（例: 一覧の再読み込み）
   */
  showWithUndo(
    message: string,
    undoPath: string,
    undoToken: string,
    onRestored?: () => void
  ): void {
    this.pendingUndo = { undoPath, undoToken, onRestored };
    this.stateSignal.set({ visible: true, message });
  }

  hide() {
    this.stateSignal.set({ visible: false, message: '' });
    this.pendingUndo = null;
  }

  /**
   * トーストの「Undo」ボタン押下時に呼ぶ。復元APIを実行し、成功時は onRestored を実行してトーストを閉じる。
   */
  performUndo(): void {
    const pending = this.pendingUndo;
    this.pendingUndo = null;
    if (!pending) {
      this.hide();
      return;
    }
    this.hide();
    const pathWithoutQuery = pending.undoPath.replace(/\?.*$/, '');
    const body = { undo_token: pending.undoToken };
    this.apiClient.post<{ status: string }>(pathWithoutQuery, body).subscribe({
      next: (res) => {
        if (res?.status === 'restored') {
          // NgZone 内で実行し、Angular の change detection が確実に発火するようにする
          this.ngZone.run(() => pending.onRestored?.());
        }
      },
      error: () => {}
    });
  }
}
