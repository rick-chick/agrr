import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { PestListView, PestListViewState } from './pest-list.view';
import { LoadPestListUseCase } from '../../../usecase/pests/load-pest-list.usecase';
import { DeletePestUseCase } from '../../../usecase/pests/delete-pest.usecase';
import { PestListPresenter } from '../../../adapters/pests/pest-list.presenter';
import { LOAD_PEST_LIST_OUTPUT_PORT } from '../../../usecase/pests/load-pest-list.output-port';
import { DELETE_PEST_OUTPUT_PORT } from '../../../usecase/pests/delete-pest.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialControl: PestListViewState = {
  loading: true,
  error: null,
  pests: []
};

@Component({
  selector: 'app-pest-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PestListPresenter,
    LoadPestListUseCase,
    DeletePestUseCase,
    { provide: LOAD_PEST_LIST_OUTPUT_PORT, useExisting: PestListPresenter },
    { provide: DELETE_PEST_OUTPUT_PORT, useExisting: PestListPresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 class="page-title">Pests</h1>
        <p class="page-description">Manage pests.</p>
      </header>
      <section class="section-card" aria-labelledby="section-list-heading">
        <h2 id="section-list-heading" class="section-title">Pest list</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else {
          <a [routerLink]="['/pests', 'new']" class="btn-primary">Create Pest</a>
          <ul class="card-list" role="list">
            @for (pest of control.pests; track pest.id) {
              <li class="card-list__item">
                <a [routerLink]="['/pests', pest.id]" class="item-card">
                  <span class="item-card__title">{{ pest.name }}</span>
                  @if (pest.name_scientific) {
                    <span class="item-card__meta">{{ pest.name_scientific }}</span>
                  }
                </a>
                <div class="list-item-actions">
                  <a [routerLink]="['/pests', pest.id, 'edit']" class="btn-secondary btn-sm">Edit</a>
                  <button type="button" class="btn-danger btn-sm" (click)="deletePest(pest.id)">Delete</button>
                </div>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrl: './pest-list.component.css'
})
export class PestListComponent implements PestListView, OnInit {
  private readonly loadUseCase = inject(LoadPestListUseCase);
  private readonly deleteUseCase = inject(DeletePestUseCase);
  private readonly presenter = inject(PestListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestListViewState = initialControl;
  get control(): PestListViewState {
    return this._control;
  }
  set control(value: PestListViewState) {
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

  deletePest(pestId: number): void {
    this.deleteUseCase.execute({ pestId, onAfterUndo: () => this.refreshAfterUndo() });
  }
}
