import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { PesticideListView, PesticideListViewState } from './pesticide-list.view';
import { LoadPesticideListUseCase } from '../../../usecase/pesticides/load-pesticide-list.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import { PesticideListPresenter } from '../../../adapters/pesticides/pesticide-list.presenter';
import { LOAD_PESTICIDE_LIST_OUTPUT_PORT } from '../../../usecase/pesticides/load-pesticide-list.output-port';
import { DELETE_PESTICIDE_OUTPUT_PORT } from '../../../usecase/pesticides/delete-pesticide.output-port';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { PesticideApiGateway } from '../../../adapters/pesticides/pesticide-api.gateway';

const initialControl: PesticideListViewState = {
  loading: true,
  error: null,
  pesticides: []
};

@Component({
  selector: 'app-pesticide-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PesticideListPresenter,
    LoadPesticideListUseCase,
    DeletePesticideUseCase,
    { provide: LOAD_PESTICIDE_LIST_OUTPUT_PORT, useExisting: PesticideListPresenter },
    { provide: DELETE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideListPresenter },
    { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">Pesticides</h1>
        <p class="page-description">Manage pesticides.</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else {
          <div class="section-card__header-actions">
            <a [routerLink]="['/pesticides', 'new']" class="btn-primary">Create Pesticide</a>
          </div>
          <ul class="card-list" role="list">
            @for (pesticide of control.pesticides; track pesticide.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/pesticides', pesticide.id]" class="item-card__body">
                    <span class="item-card__title">{{ pesticide.name }}</span>
                    @if (pesticide.active_ingredient) {
                      <span class="item-card__meta">{{ pesticide.active_ingredient }}</span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/pesticides', pesticide.id, 'edit']" class="btn-secondary">Edit</a>
                    <button type="button" class="btn-danger" (click)="deletePesticide(pesticide.id)" aria-label="Delete">Delete</button>
                  </div>
                </article>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrls: ['./pesticide-list.component.css']
})
export class PesticideListComponent implements PesticideListView, OnInit {
  private readonly loadUseCase = inject(LoadPesticideListUseCase);
  private readonly deleteUseCase = inject(DeletePesticideUseCase);
  private readonly presenter = inject(PesticideListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PesticideListViewState = initialControl;
  get control(): PesticideListViewState {
    return this._control;
  }
  set control(value: PesticideListViewState) {
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

  deletePesticide(pesticideId: number): void {
    this.deleteUseCase.execute({ pesticideId, onAfterUndo: () => this.refreshAfterUndo() });
  }
}
