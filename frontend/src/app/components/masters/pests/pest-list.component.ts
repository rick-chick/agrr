import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PestListView, PestListViewState } from './pest-list.view';
import { LoadPestListUseCase } from '../../../usecase/pests/load-pest-list.usecase';
import { DeletePestUseCase } from '../../../usecase/pests/delete-pest.usecase';
import { PestListPresenter, PEST_LIST_PROVIDERS } from '../../../usecase/pests/pest-list.providers';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../../core/list-refresh/list-refresh-keys';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';

const initialControl: PestListViewState = {
  loading: true,
  error: null,
  pests: [],
  pendingUndoToast: null
};

@Component({
  selector: 'app-pest-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...PEST_LIST_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'pests.index.title' | translate }}</h1>
        <p class="page-description">{{ 'pests.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <div class="section-card__header-actions">
            <a [routerLink]="['/pests', 'new']" class="btn-primary">{{ 'pests.index.new_pest' | translate }}</a>
          </div>
          <ul class="card-list" role="list">
            @for (pest of control.pests; track pest.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/pests', pest.id]" class="item-card__body">
                    <span class="item-card__title">{{ pest.name }}</span>
                    @if (pest.name_scientific) {
                      <span class="item-card__meta">{{ pest.name_scientific }}</span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/pests', pest.id, 'edit']" class="btn-secondary">
                      {{ 'pests.index.actions.edit' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn-danger"
                      (click)="deletePest(pest.id)"
                      [attr.aria-label]="'pests.index.actions.delete' | translate"
                    >
                      {{ 'pests.index.actions.delete' | translate }}
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
  styleUrls: ['./pest-list.component.css']
})
export class PestListComponent implements PestListView, OnInit, OnDestroy {
  private readonly loadUseCase = inject(LoadPestListUseCase);
  private readonly deleteUseCase = inject(DeletePestUseCase);
  private readonly presenter = inject(PestListPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly listRefreshBus = inject(ListRefreshBus);
  private unsubRefresh: (() => void) | null = null;

  private _control: PestListViewState = initialControl;
  get control(): PestListViewState {
    return this._control;
  }
  set control(value: PestListViewState) {
    this._control = applyPendingUndoToastViewEffects(value, { toast: this.undoToast });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
    this.unsubRefresh = this.listRefreshBus.onRefresh(LIST_REFRESH_CHANNEL.pests, () => this.refreshAfterUndo());
  }

  ngOnDestroy(): void {
    this.unsubRefresh?.();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute();
  }

  /** UNDO 後の再取得。ローディング表示にせず一覧を更新する。 */
  refreshAfterUndo(): void {
    this.loadUseCase.execute();
  }

  deletePest(pestId: number): void {
    this.deleteUseCase.execute({ pestId, onAfterUndo: () => this.refreshAfterUndo() });
  }
}
