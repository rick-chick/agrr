import { Injectable } from '@angular/core';
import { Subject, Subscription } from 'rxjs';
import type { ListRefreshChannelId } from './list-refresh-keys';

/**
 * マスタ一覧の再読込をチャンネル単位で通知するバス（旧 *-list-refresh.service.ts の集約）。
 */
@Injectable({ providedIn: 'root' })
export class ListRefreshBus {
  private readonly channels = new Map<ListRefreshChannelId, Subject<void>>();

  private subjectFor(channel: ListRefreshChannelId): Subject<void> {
    let s = this.channels.get(channel);
    if (!s) {
      s = new Subject<void>();
      this.channels.set(channel, s);
    }
    return s;
  }

  /** 一覧の再読込が必要なときに呼ぶ。 */
  refresh(channel: ListRefreshChannelId): void {
    this.subjectFor(channel).next();
  }

  /** 再読込を購読。戻り値で unsubscribe。 */
  onRefresh(channel: ListRefreshChannelId, callback: () => void): () => void {
    const sub: Subscription = this.subjectFor(channel).subscribe(callback);
    return () => sub.unsubscribe();
  }
}
