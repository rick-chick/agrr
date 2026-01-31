import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FertilizeListView, FertilizeListViewState } from './fertilize-list.view';
import { Fertilize } from '../../../domain/fertilizes/fertilize';
import { LoadFertilizeListUseCase } from '../../../usecase/fertilizes/load-fertilize-list.usecase';
import { DeleteFertilizeUseCase } from '../../../usecase/fertilizes/delete-fertilize.usecase';
import { FertilizeListPresenter } from '../../../adapters/fertilizes/fertilize-list.presenter';
import { LOAD_FERTILIZE_LIST_OUTPUT_PORT } from '../../../usecase/fertilizes/load-fertilize-list.output-port';
import { DELETE_FERTILIZE_OUTPUT_PORT } from '../../../usecase/fertilizes/delete-fertilize.output-port';
import { FERTILIZE_GATEWAY } from '../../../usecase/fertilizes/fertilize-gateway';
import { FertilizeApiGateway } from '../../../adapters/fertilizes/fertilize-api.gateway';

const initialControl: FertilizeListViewState = {
  loading: true,
  error: null,
  fertilizes: []
};

@Component({
  selector: 'app-fertilize-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    FertilizeListPresenter,
    LoadFertilizeListUseCase,
    DeleteFertilizeUseCase,
    { provide: LOAD_FERTILIZE_LIST_OUTPUT_PORT, useExisting: FertilizeListPresenter },
    { provide: DELETE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeListPresenter },
    { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">Fertilizes</h1>
        <p class="page-description">Manage fertilizes.</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else {
          <div class="section-card__header-actions">
            <a routerLink="/fertilizes/new" class="btn-primary">Create Fertilize</a>
          </div>
          @if (control.fertilizes.length === 0) {
            <div class="empty-state">
              <p class="empty-state__message">No fertilizes found.</p>
              <p class="empty-state__description">Create your first fertilize to get started.</p>
            </div>
          } @else {
            <ul class="card-list" role="list">
            @for (item of control.fertilizes; track item.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/fertilizes', item.id]" class="item-card__body">
                    <span class="item-card__title">{{ item.name }}</span>
                    <span class="item-card__meta">NPK: {{ formatNpk(item) }}</span>
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/fertilizes', item.id, 'edit']" class="btn-secondary">Edit</a>
                    <button type="button" class="btn-danger" (click)="deleteFertilize(item.id)" aria-label="Delete">Delete</button>
                  </div>
                </article>
              </li>
            }
          </ul>
          }
        }
      </section>
    </main>
  `,
  styleUrl: './fertilize-list.component.css'
})
export class FertilizeListComponent implements FertilizeListView, OnInit {
  private readonly loadUseCase = inject(LoadFertilizeListUseCase);
  private readonly deleteUseCase = inject(DeleteFertilizeUseCase);
  private readonly presenter = inject(FertilizeListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeListViewState = initialControl;
  get control(): FertilizeListViewState {
    return this._control;
  }
  set control(value: FertilizeListViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute();
  }

  /** UNDO 後の再取得。ローディング表示にせず一覧を更新する。 */
  refreshAfterUndo(): void {
    this.loadUseCase.execute();
  }

  deleteFertilize(fertilizeId: number): void {
    this.deleteUseCase.execute({ fertilizeId, onAfterUndo: () => this.refreshAfterUndo() });
  }

  formatNpk(item: Fertilize): string {
    const n = item.n ?? '-';
    const p = item.p ?? '-';
    const k = item.k ?? '-';
    return `${n}/${p}/${k}`;
  }
}
