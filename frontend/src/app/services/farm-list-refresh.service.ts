import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

/**
 * 農場一覧の再読込をトリガーするためのサービス。
 * 農場詳細から削除→一覧へ遷移→Undo の流れで、一覧側が復元結果を反映するために使用する。
 */
@Injectable({ providedIn: 'root' })
export class FarmListRefreshService {
  private readonly refresh$ = new Subject<void>();

  /** 一覧再読込が必要なときに購読元へ通知する。 */
  refresh(): void {
    this.refresh$.next();
  }

  /** 再読込トリガーを購読する。 */
  onRefresh(callback: () => void): () => void {
    const sub = this.refresh$.subscribe(callback);
    return () => sub.unsubscribe();
  }
}
