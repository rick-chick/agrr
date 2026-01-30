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
    <section class="page">
      <h2>Farms</h2>
      <a routerLink="/farms/new">Create Farm</a>
      @if (control.loading) {
        <p class="loading">Loading...</p>
      } @else if (control.error) {
        <p class="error">Error: {{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let farm of control.farms">
            <a [routerLink]="['/farms', farm.id]">{{ farm.name }}</a>
            <button type="button" (click)="deleteFarm(farm.id)">Delete</button>
          </li>
        </ul>
      }
    </section>
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
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute();
  }

  deleteFarm(farmId: number): void {
    if (!confirm('Delete this farm?')) return;
    this.deleteUseCase.execute({ farmId });
  }
}
