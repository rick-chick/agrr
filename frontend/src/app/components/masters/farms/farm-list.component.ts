import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { FarmListView, FarmListViewState } from './farm-list.view';
import { LoadFarmListUseCase } from '../../../usecase/farms/load-farm-list.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { FarmListPresenter } from '../../../adapters/farms/farm-list.presenter';
import { LOAD_FARM_LIST_OUTPUT_PORT } from '../../../usecase/farms/load-farm-list.output-port';
import { DELETE_FARM_OUTPUT_PORT } from '../../../usecase/farms/delete-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmApiGateway } from '../../../adapters/farms/farm-api.gateway';

const initialControl: FarmListViewState = {
  loading: true,
  error: null,
  farms: []
};

@Component({
  selector: 'app-farm-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    FarmListPresenter,
    LoadFarmListUseCase,
    DeleteFarmUseCase,
    { provide: LOAD_FARM_LIST_OUTPUT_PORT, useExisting: FarmListPresenter },
    { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmListPresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway }
  ],
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
export class FarmListComponent implements FarmListView, OnInit {
  private readonly loadUseCase = inject(LoadFarmListUseCase);
  private readonly deleteUseCase = inject(DeleteFarmUseCase);
  private readonly presenter = inject(FarmListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FarmListViewState = initialControl;
  get control(): FarmListViewState {
    return this._control;
  }
  set control(value: FarmListViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
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
