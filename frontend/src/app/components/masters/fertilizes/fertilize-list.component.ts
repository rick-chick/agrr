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
    <section class="page">
      <h2>Fertilizes</h2>
      <a routerLink="/fertilizes/new">Create Fertilize</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let item of control.fertilizes">
            <a [routerLink]="['/fertilizes', item.id]"><strong>{{ item.name }}</strong></a>
            <span> (NPK: {{ formatNpk(item) }})</span>
            <a [routerLink]="['/fertilizes', item.id, 'edit']">Edit</a>
            <button type="button" (click)="deleteFertilize(item.id)">Delete</button>
          </li>
        </ul>
      }
    </section>
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

  deleteFertilize(fertilizeId: number): void {
    this.deleteUseCase.execute({ fertilizeId, onAfterUndo: () => this.load() });
  }

  formatNpk(item: Fertilize): string {
    const n = item.n ?? '-';
    const p = item.p ?? '-';
    const k = item.k ?? '-';
    return `${n}/${p}/${k}`;
  }
}
