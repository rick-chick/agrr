import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropListView, CropListViewState } from './crop-list.view';
import { LoadCropListUseCase } from '../../../usecase/crops/load-crop-list.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { CropListPresenter } from '../../../adapters/crops/crop-list.presenter';
import { LOAD_CROP_LIST_OUTPUT_PORT } from '../../../usecase/crops/load-crop-list.output-port';
import { DELETE_CROP_OUTPUT_PORT } from '../../../usecase/crops/delete-crop.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';

const initialControl: CropListViewState = {
  loading: true,
  error: null,
  crops: []
};

@Component({
  selector: 'app-crop-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    CropListPresenter,
    LoadCropListUseCase,
    DeleteCropUseCase,
    { provide: LOAD_CROP_LIST_OUTPUT_PORT, useExisting: CropListPresenter },
    { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropListPresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 class="page-title">{{ 'crops.index.title' | translate }}</h1>
        <p class="page-description">{{ 'crops.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="section-list-heading">
        <h2 id="section-list-heading" class="section-title">{{ 'crops.index.list_heading' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <p class="master-error">{{ control.error }}</p>
        } @else {
          <a [routerLink]="['/crops', 'new']" class="btn-primary">{{ 'crops.index.new_crop' | translate }}</a>
          <ul class="card-list" role="list">
            @for (crop of control.crops; track crop.id) {
              <li class="card-list__item">
                <a [routerLink]="['/crops', crop.id]" class="item-card">
                  <span class="item-card__title">{{ crop.name }}</span>
                  @if (crop.variety) {
                    <span class="item-card__meta">{{ crop.variety }}</span>
                  }
                </a>
                <div class="list-item-actions">
                  <a [routerLink]="['/crops', crop.id, 'edit']" class="btn-secondary btn-sm">{{ 'common.edit' | translate }}</a>
                  <button type="button" class="btn-danger btn-sm" (click)="deleteCrop(crop.id)">
                    {{ 'common.delete' | translate }}
                  </button>
                </div>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrl: './crop-list.component.css'
})
export class CropListComponent implements CropListView, OnInit {
  private readonly loadUseCase = inject(LoadCropListUseCase);
  private readonly deleteUseCase = inject(DeleteCropUseCase);
  private readonly presenter = inject(CropListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropListViewState = initialControl;
  get control(): CropListViewState {
    return this._control;
  }
  set control(value: CropListViewState) {
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

  deleteCrop(cropId: number): void {
    this.deleteUseCase.execute({ cropId, onAfterUndo: () => this.load() });
  }
}
