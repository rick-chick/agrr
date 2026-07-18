import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef, signal } from '@angular/core';
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
import { CropListStagesPanelComponent } from './crop-list-stages-panel.component';
import { CropListBlueprintsPanelComponent } from './crop-list-blueprints-panel.component';

type CropListExpandPanel = 'stages' | 'blueprints';

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
  imports: [
    CommonModule,
    RouterLink,
    TranslateModule,
    CropListStagesPanelComponent,
    CropListBlueprintsPanelComponent
  ],
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
                  <div class="item-card__body">
                    <span class="item-card__title">{{ crop.name }}</span>
                    @if (crop.variety) {
                      <span class="item-card__meta">{{ crop.variety }}</span>
                    }
                    @if (auth.user()?.admin && crop.is_reference) {
                      <span class="item-card__badge">{{ 'crops.show.reference_crop' | translate }}</span>
                    }
                  </div>
                  <div class="item-card__primary-actions">
                    <a
                      [routerLink]="['/crops', crop.id]"
                      class="btn btn-secondary btn-sm"
                      data-testid="crop-detail-link"
                    >
                      {{ 'crops.index.actions.show' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn-link"
                      data-testid="crop-stages-toggle"
                      [attr.aria-expanded]="isPanelExpanded(crop.id, 'stages')"
                      [attr.aria-controls]="stagesPanelId(crop.id)"
                      (click)="togglePanel(crop.id, 'stages')"
                    >
                      {{
                        isPanelExpanded(crop.id, 'stages')
                          ? ('crops.index.inline.collapse' | translate)
                          : ('crops.index.inline.stages_toggle' | translate)
                      }}
                    </button>
                    <button
                      type="button"
                      class="btn-link"
                      data-testid="crop-blueprints-toggle"
                      [attr.aria-expanded]="isPanelExpanded(crop.id, 'blueprints')"
                      [attr.aria-controls]="blueprintsPanelId(crop.id)"
                      (click)="togglePanel(crop.id, 'blueprints')"
                    >
                      {{
                        isPanelExpanded(crop.id, 'blueprints')
                          ? ('crops.index.inline.collapse' | translate)
                          : ('crops.index.inline.blueprints_toggle' | translate)
                      }}
                    </button>
                  </div>
                  @if (isPanelExpanded(crop.id, 'stages')) {
                    <div [id]="stagesPanelId(crop.id)">
                      <app-crop-list-stages-panel [cropId]="crop.id" />
                    </div>
                  }
                  @if (isPanelExpanded(crop.id, 'blueprints')) {
                    <div [id]="blueprintsPanelId(crop.id)">
                      <app-crop-list-blueprints-panel [cropId]="crop.id" />
                    </div>
                  }
                  <div class="item-card__actions">
                    <a [routerLink]="['/crops', crop.id, 'edit']" class="btn btn-secondary">{{ 'common.edit' | translate }}</a>
                    <button type="button" class="btn btn-danger" (click)="deleteCrop(crop.id)" [attr.aria-label]="'common.delete' | translate">
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

  readonly expandedPanel = signal<Map<number, CropListExpandPanel>>(new Map());

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

  togglePanel(cropId: number, panel: CropListExpandPanel): void {
    const next = new Map(this.expandedPanel());
    if (next.get(cropId) === panel) {
      next.delete(cropId);
    } else {
      next.set(cropId, panel);
    }
    this.expandedPanel.set(next);
  }

  isPanelExpanded(cropId: number, panel: CropListExpandPanel): boolean {
    return this.expandedPanel().get(cropId) === panel;
  }

  stagesPanelId(cropId: number): string {
    return `crop-list-stages-panel-${cropId}`;
  }

  blueprintsPanelId(cropId: number): string {
    return `crop-list-blueprints-panel-${cropId}`;
  }
}
