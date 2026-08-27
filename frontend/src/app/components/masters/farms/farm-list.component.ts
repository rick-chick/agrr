import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef, ElementRef, ViewChild } from '@angular/core';
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
import { CardListSkeletonComponent } from '../../shared/skeleton/card-list-skeleton.component';

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
  imports: [CommonModule, RouterLink, TranslateModule, CardListSkeletonComponent],
  providers: [...FARM_LIST_PROVIDERS],
  template: `
    <div class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'farms.index.title' | translate }}</h1>
        <p class="page-description">{{ 'farms.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <app-card-list-skeleton class="list-loading-skeleton" />
          <p class="master-loading list-loading-text">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error farm-list__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn btn-secondary farm-list__retry" (click)="load()">
              {{ 'masters.load_error.retry' | translate }}
            </button>
          </div>
        } @else {
          <div class="section-card__header-actions">
            <a routerLink="/farms/new" class="btn btn-primary">{{ 'farms.index.new_farm' | translate }}</a>
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
                      <span class="item-card__meta">{{ 'farms.form.region_' + farm.region | translate }}</span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/farms', farm.id, 'edit']" class="btn btn-secondary">
                      {{ 'common.edit' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn btn-danger"
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
    </div>

    <dialog
      #deleteConfirmDialog
      class="confirm-dialog farm-list__delete-confirm"
      (cancel)="cancelDeleteConfirmDialog($event)"
      (click)="onDeleteConfirmDialogBackdropClick($event)"
    >
      @if (pendingDeleteFarmId != null) {
        <p class="confirm-dialog__message">{{ 'farms.index.delete_confirm_message' | translate }}</p>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn btn-secondary" (click)="cancelDeleteConfirmDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn btn-danger" (click)="confirmDeleteFarm()">
            {{ 'common.delete' | translate }}
          </button>
        </div>
      }
    </dialog>
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

  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;

  pendingDeleteFarmId: number | null = null;

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
    this.pendingDeleteFarmId = farmId;
    this.deleteConfirmDialogRef?.nativeElement?.showModal();
  }

  confirmDeleteFarm(): void {
    if (this.pendingDeleteFarmId == null) {
      return;
    }
    const farmId = this.pendingDeleteFarmId;
    this.pendingDeleteFarmId = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
    this.deleteUseCase.execute({ farmId, onAfterUndo: () => this.refreshAfterUndo() });
  }

  cancelDeleteConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingDeleteFarmId = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
  }

  onDeleteConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.deleteConfirmDialogRef?.nativeElement) {
      this.cancelDeleteConfirmDialog();
    }
  }
}
