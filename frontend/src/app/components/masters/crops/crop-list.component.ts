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
    <section class="page">
      <h2>{{ 'crops.index.title' | translate }}</h2>
      <a [routerLink]="['/crops', 'new']" class="btn btn-primary">{{ 'crops.index.new_crop' | translate }}</a>
      @if (control.loading) {
        <p>{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <div class="enhanced-grid">
          @for (crop of control.crops; track crop.id) {
            <div class="enhanced-selection-card-wrapper">
              <a [routerLink]="['/crops', crop.id]" class="enhanced-selection-card">
                <div class="enhanced-card-icon">🥬</div>
                <div class="enhanced-card-title">{{ crop.name }}</div>
                <div class="enhanced-card-subtitle" *ngIf="crop.variety">{{ crop.variety }}</div>
              </a>
              <a [routerLink]="['/crops', crop.id, 'edit']" class="btn btn-sm">{{ 'common.edit' | translate }}</a>
              <button type="button" class="btn btn-sm btn-danger" (click)="deleteCrop(crop.id)">
                {{ 'common.delete' | translate }}
              </button>
            </div>
          }
        </div>
      }
    </section>
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
