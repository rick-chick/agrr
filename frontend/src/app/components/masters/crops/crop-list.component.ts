import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { CropListView, CropListViewState } from './crop-list.view';
import { LoadCropListUseCase } from '../../../usecase/crops/load-crop-list.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import {
  CropListPresenter,
  CROP_LIST_PROVIDERS
} from '../../../usecase/crops/crop-list.providers';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../../core/list-refresh/list-refresh-keys';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: CropListViewState = {
  loading: true,
  error: null,
  crops: [],
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-crop-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...CROP_LIST_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'crops.index.title' | translate }}</h1>
        <p class="page-description">{{ 'crops.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <div class="section-card__header-actions">
            <a [routerLink]="['/crops', 'new']" class="btn btn-primary">{{ 'crops.index.new_crop' | translate }}</a>
          </div>
          <ul class="card-list" role="list">
            @for (crop of control.crops; track crop.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/crops', crop.id]" class="item-card__body">
                    <span class="item-card__title">{{ crop.name }}</span>
                    @if (crop.variety) {
                      <span class="item-card__meta">{{ crop.variety }}</span>
                    }
                    @if (auth.user()?.admin && crop.is_reference) {
                      <span class="item-card__badge">{{ 'crops.show.reference_crop' | translate }}</span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/crops', crop.id, 'edit']" class="btn btn-secondary">{{ 'common.edit' | translate }}</a>
                    <button
                      type="button"
                      class="btn btn-danger"
                      (click)="deleteCrop(crop.id)"
                      [attr.aria-label]="'common.delete' | translate"
                    >
                      {{ 'common.delete' | translate }}
                    </button>
                    <div class="crop-overflow-menu" data-testid="crop-overflow-menu">
                      <button
                        type="button"
                        class="btn btn-secondary btn-sm crop-overflow-menu__trigger"
                        data-testid="crop-overflow-menu-trigger"
                        [attr.aria-expanded]="openMenuCropId === crop.id"
                        [attr.aria-controls]="overflowMenuPanelId(crop.id)"
                        aria-haspopup="menu"
                        [attr.aria-label]="'crops.index.menu.more_actions' | translate"
                        (click)="toggleOverflowMenu(crop.id, $event)"
                      >
                        <svg class="crop-overflow-menu__icon" viewBox="0 0 24 24" aria-hidden="true">
                          <path
                            fill="currentColor"
                            d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"
                          />
                        </svg>
                      </button>
                      @if (openMenuCropId === crop.id) {
                        <div
                          class="crop-overflow-menu__panel"
                          [id]="overflowMenuPanelId(crop.id)"
                          role="menu"
                          data-testid="crop-overflow-menu-panel"
                        >
                          <a
                            class="crop-overflow-menu__item"
                            [routerLink]="['/crops', crop.id, 'stages']"
                            role="menuitem"
                            data-testid="crop-stages-link"
                            (click)="closeOverflowMenu()"
                          >
                            {{ 'crops.index.inline.stages_toggle' | translate }}
                          </a>
                          <a
                            class="crop-overflow-menu__item"
                            [routerLink]="['/crops', crop.id, 'task_schedule_blueprints']"
                            role="menuitem"
                            data-testid="crop-blueprints-link"
                            (click)="closeOverflowMenu()"
                          >
                            {{ 'crops.index.inline.blueprints_toggle' | translate }}
                          </a>
                        </div>
                      }
                    </div>
                  </div>
                </article>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrls: ['./crop-list.component.css']
})
export class CropListComponent implements CropListView, OnInit, OnDestroy {
  readonly auth = inject(AuthService);
  private readonly loadUseCase = inject(LoadCropListUseCase);
  private readonly deleteUseCase = inject(DeleteCropUseCase);
  private readonly presenter = inject(CropListPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly listRefreshBus = inject(ListRefreshBus);
  private unsubRefresh: (() => void) | null = null;

  openMenuCropId: number | null = null;

  private _control: CropListViewState = initialControl;
  get control(): CropListViewState {
    return this._control;
  }
  set control(value: CropListViewState) {
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
    this.unsubRefresh = this.listRefreshBus.onRefresh(LIST_REFRESH_CHANNEL.crops, () => this.refreshAfterUndo());
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

  deleteCrop(cropId: number): void {
    this.deleteUseCase.execute({ cropId, onAfterUndo: () => this.refreshAfterUndo() });
  }

  toggleOverflowMenu(cropId: number, event: MouseEvent): void {
    event.stopPropagation();
    this.openMenuCropId = this.openMenuCropId === cropId ? null : cropId;
  }

  closeOverflowMenu(): void {
    this.openMenuCropId = null;
  }

  overflowMenuPanelId(cropId: number): string {
    return `crop-overflow-menu-panel-${cropId}`;
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    this.dismissOverflowMenuIfOutside(event.target);
  }

  @HostListener('document:keydown', ['$event'])
  onDocumentKeydown(event: KeyboardEvent): void {
    if (this.openMenuCropId === null || event.key !== 'Escape') {
      return;
    }
    event.preventDefault();
    this.closeOverflowMenu();
  }

  private dismissOverflowMenuIfOutside(target: EventTarget | null): void {
    if (this.openMenuCropId === null) {
      return;
    }
    if (target instanceof Element && target.closest('[data-testid="crop-overflow-menu"]')) {
      return;
    }
    this.closeOverflowMenu();
  }
}
