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
    <section class="page">
      <h2>Pests</h2>
      <a [routerLink]="['/pests', 'new']" class="btn btn-primary">Create Pest</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <div class="enhanced-grid">
          @for (pest of control.pests; track pest.id) {
            <div class="enhanced-selection-card-wrapper">
              <a [routerLink]="['/pests', pest.id]" class="enhanced-selection-card">
                <div class="enhanced-card-icon">🐛</div>
                <div class="enhanced-card-title">{{ pest.name }}</div>
                <div class="enhanced-card-subtitle" *ngIf="pest.name_scientific">{{ pest.name_scientific }}</div>
              </a>
              <a [routerLink]="['/pests', pest.id, 'edit']" class="btn btn-sm">Edit</a>
              <button type="button" class="btn btn-sm btn-danger" (click)="deletePest(pest.id)">
                Delete
              </button>
            </div>
          }
        </div>
      }
    </section>
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

  deletePest(pestId: number): void {
    this.deleteUseCase.execute({ pestId, onAfterUndo: () => this.load() });
  }
}
