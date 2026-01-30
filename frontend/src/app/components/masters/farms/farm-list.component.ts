import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
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
  imports: [CommonModule, RouterLink],
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
        <h1 class="page-title">Farms</h1>
        <p class="page-description">Manage your farms.</p>
      </header>
      <section class="section-card" aria-labelledby="section-list-heading">
        <h2 id="section-list-heading" class="section-title">Farm list</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="master-error">{{ control.error }}</p>
        } @else {
          <a routerLink="/farms/new" class="btn-primary">Create Farm</a>
          <ul class="card-list" role="list">
            @for (farm of control.farms; track farm.id) {
              <li class="card-list__item">
                <a [routerLink]="['/farms', farm.id]" class="item-card">
                  <span class="item-card__title">{{ farm.name }}</span>
                  @if (farm.region) {
                    <span class="item-card__meta">{{ farm.region }}</span>
                  }
                </a>
                <div class="list-item-actions">
                  <a [routerLink]="['/farms', farm.id, 'edit']" class="btn-secondary btn-sm">Edit</a>
                  <button type="button" class="btn-danger btn-sm" (click)="deleteFarm(farm.id)">Delete</button>
                </div>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrl: './farm-list.component.css'
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

  deleteFarm(farmId: number): void {
    this.deleteUseCase.execute({ farmId, onAfterUndo: () => this.load() });
  }
}
