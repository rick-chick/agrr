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
    <section class="page">
      <h2>Pesticides</h2>
      <a [routerLink]="['/pesticides', 'new']" class="btn btn-primary">Create Pesticide</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <div class="enhanced-grid">
          @for (pesticide of control.pesticides; track pesticide.id) {
            <div class="enhanced-selection-card-wrapper">
              <a [routerLink]="['/pesticides', pesticide.id]" class="enhanced-selection-card">
                <div class="enhanced-card-icon">🌱</div>
                <div class="enhanced-card-title">{{ pesticide.name }}</div>
                <div class="enhanced-card-subtitle" *ngIf="pesticide.active_ingredient">{{ pesticide.active_ingredient }}</div>
              </a>
              <a [routerLink]="['/pesticides', pesticide.id, 'edit']" class="btn btn-sm">Edit</a>
              <button type="button" class="btn btn-sm btn-danger" (click)="deletePesticide(pesticide.id)">
                Delete
              </button>
            </div>
          }
        </div>
      }
    </section>
  `,
  styleUrl: './pesticide-list.component.css'
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

  deletePesticide(pesticideId: number): void {
    this.deleteUseCase.execute({ pesticideId, onAfterUndo: () => this.load() });
  }
}
