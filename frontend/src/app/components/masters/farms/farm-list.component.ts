import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { FarmListView, FarmListViewState } from './farm-list.view';
import { LoadFarmListUseCase } from '../../../usecase/farms/load-farm-list.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import {
  FarmListPresenter,
  FARM_LIST_PROVIDERS
} from '../../../usecase/farms/farm-list.providers';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../../core/list-refresh/list-refresh-keys';
import { UndoToastService } from '../../../services/undo-toast.service';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: FarmListViewState = {
  loading: true,
  error: null,
  farms: [],
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-farm-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...FARM_LIST_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'farms.index.title' | translate }}</h1>
        <p class="page-description">{{ 'farms.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <div class="section-card__header-actions">
            <a routerLink="/farms/new" class="btn-primary">{{ 'farms.index.new_farm' | translate }}</a>
          </div>
          <ul class="card-list" role="list">
            @for (farm of control.farms; track farm.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/farms', farm.id]" class="item-card__body">
                    <span class="item-card__title">
                      {{ farm.name }}
                      @if (farm.is_reference) {
                        <span>({{ 'farms.index.reference_badge' | translate }})</span>
                      }
                    </span>
                    @if (farm.region) {
                      <span class="item-card__meta">{{ farm.region }}</span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/farms', farm.id, 'edit']" class="btn-secondary">
                      {{ 'common.edit' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn-danger"
                      (click)="deleteFarm(farm.id)"
                      [attr.aria-label]="'common.delete' | translate"
                    >
                      {{ 'common.delete' | translate }}
                    </button>
                  </div>
                </article>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrls: ['./farm-list.component.css']
})
export class FarmListComponent implements FarmListView, OnInit, OnDestroy {
  private readonly loadUseCase = inject(LoadFarmListUseCase);
  private readonly deleteUseCase = inject(DeleteFarmUseCase);
  private readonly presenter = inject(FarmListPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly listRefreshBus = inject(ListRefreshBus);
  private unsubRefresh: (() => void) | null = null;

  private _control: FarmListViewState = initialControl;
  get control(): FarmListViewState {
    return this._control;
  }
  set control(value: FarmListViewState) {
    const next = applyPendingUndoToastViewEffects(
      applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage }),
      { toast: this.undoToast }
    );
    this._control = next;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
    this.unsubRefresh = this.listRefreshBus.onRefresh(LIST_REFRESH_CHANNEL.farms, () => this.refreshAfterUndo());
  }

  ngOnDestroy(): void {
    this.unsubRefresh?.();
  }

  load(): void {
    this.loadUseCase.execute();
  }

  /** UNDO 後の再取得。ローディング表示にせず一覧を更新する。 */
  refreshAfterUndo(): void {
    this.loadUseCase.execute();
  }

  deleteFarm(farmId: number): void {
    this.deleteUseCase.execute({ farmId, onAfterUndo: () => this.refreshAfterUndo() });
  }
}
