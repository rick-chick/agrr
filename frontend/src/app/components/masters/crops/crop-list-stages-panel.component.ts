import { Component, Input, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { CropListStagesPanelView, CropListStagesPanelViewState } from './crop-list-stages-panel.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import {
  CropListStagesPanelPresenter,
  CROP_LIST_STAGES_PANEL_PROVIDERS
} from '../../../usecase/crops/crop-list-stages-panel.providers';
import { sortStagesByOrder } from '../../../domain/crops/crop-stage-order';
import type { TemperatureRequirement } from '../../../domain/crops/crop';

const initialControl: CropListStagesPanelViewState = {
  loading: true,
  error: null,
  crop: null
};

@Component({
  selector: 'app-crop-list-stages-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...CROP_LIST_STAGES_PANEL_PROVIDERS],
  template: `
    <div class="crop-list-panel crop-list-stages-panel" data-testid="crop-list-stages-panel">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-error">{{ control.error | translate }}</p>
      } @else if (control.crop) {
        @if (!canMutateStages) {
          <div class="crop-list-panel__readonly-notice" role="status">
            <p>{{ 'crops.edit.reference_stages_readonly' | translate }}</p>
          </div>
        }

        @if (sortedStages.length === 0) {
          <p class="crop-list-panel__empty">{{ 'crops.show.no_stages_description' | translate }}</p>
        } @else {
          <ul class="crop-list-panel__stage-list" role="list">
            @for (stage of sortedStages; track stage.id) {
              <li class="crop-list-panel__stage-item" role="listitem">
                <span class="crop-list-panel__stage-name">{{ stage.name }}</span>
                <span class="crop-list-panel__stage-meta">
                  {{ 'crops.edit.table_order' | translate }}: {{ stage.order }}
                </span>
                <span class="crop-list-panel__stage-meta">
                  {{ 'crops.edit.table_optimal_range' | translate }}:
                  {{ formatOptimalTemperatureRange(stage.temperature_requirement) }}
                </span>
              </li>
            }
          </ul>
        }

        <div class="crop-list-panel__footer">
          <a [routerLink]="['/crops', cropId, 'stages']" class="btn btn-secondary btn-sm">
            {{ 'crops.index.inline.stages_full_edit' | translate }}
          </a>
        </div>
      }
    </div>
  `,
  styleUrls: ['./crop-list-panel.shared.css']
})
export class CropListStagesPanelComponent implements CropListStagesPanelView, OnInit {
  @Input({ required: true }) cropId!: number;

  readonly auth = inject(AuthService);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly presenter = inject(CropListStagesPanelPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: CropListStagesPanelViewState = initialControl;
  get control(): CropListStagesPanelViewState {
    return this._control;
  }
  set control(value: CropListStagesPanelViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  get sortedStages() {
    return sortStagesByOrder(this.control.crop?.crop_stages ?? []);
  }

  get canMutateStages(): boolean {
    if (!this.control.crop?.is_reference) {
      return true;
    }
    return this.auth.user()?.admin ?? false;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  formatOptimalTemperatureRange(
    requirement: TemperatureRequirement | null | undefined
  ): string {
    if (requirement == null) {
      return this.translate.instant('crops.edit.value_missing');
    }

    const min = requirement.optimal_min;
    const max = requirement.optimal_max;
    const unit = this.translate.instant('crops.show.celsius_unit');
    const hasMin = min != null && Number.isFinite(min);
    const hasMax = max != null && Number.isFinite(max);

    if (hasMin && hasMax) {
      return `${min}${unit} – ${max}${unit}`;
    }
    if (hasMin) {
      return `${min}${unit}`;
    }
    if (hasMax) {
      return `${max}${unit}`;
    }
    return this.translate.instant('crops.edit.value_missing');
  }
}
