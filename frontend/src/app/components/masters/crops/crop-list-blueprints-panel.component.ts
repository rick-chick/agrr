import { Component, Input, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropListBlueprintsPanelView, CropListBlueprintsPanelViewState } from './crop-list-blueprints-panel.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import {
  CropListBlueprintsPanelPresenter,
  CROP_LIST_BLUEPRINTS_PANEL_PROVIDERS
} from '../../../usecase/crops/crop-list-blueprints-panel.providers';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';

const initialControl: CropListBlueprintsPanelViewState = {
  loading: true,
  error: null,
  crop: null,
  blueprintsLoading: true,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null
};

@Component({
  selector: 'app-crop-list-blueprints-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...CROP_LIST_BLUEPRINTS_PANEL_PROVIDERS],
  template: `
    <div class="crop-list-panel crop-list-blueprints-panel" data-testid="crop-list-blueprints-panel">
      @if (control.loading || control.blueprintsLoading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-error">{{ control.error | translate }}</p>
      } @else if (control.crop) {
        <div class="blueprint-readiness" role="status">
          <p class="blueprint-readiness__title">
            {{ 'crops.show.blueprint_readiness.detail_title' | translate }}
          </p>
          <ul class="blueprint-readiness__list">
            <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.stageRequirementsReady">
              @if (control.blueprintReadiness.stageRequirementsReady) {
                <span>{{ 'crops.show.blueprint_readiness.stages_ready' | translate }}</span>
              } @else {
                <span>{{ 'crops.show.blueprint_readiness.stages_missing' | translate }}</span>
              }
            </li>
            <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.blueprintsReady">
              @if (control.blueprintReadiness.blueprintsReady) {
                <span>{{ 'crops.show.blueprint_readiness.blueprints_ready' | translate }}</span>
              } @else {
                <span>{{ 'crops.show.blueprint_readiness.blueprints_missing' | translate }}</span>
              }
            </li>
          </ul>
        </div>

        <p class="crop-list-panel__blueprint-count">
          {{
            'crops.show.blueprint_summary.count'
              | translate: { count: control.blueprintCount }
          }}
          @if (control.blueprintSummary && control.blueprintSummary.attentionCount > 0) {
            <span class="crop-list-panel__blueprint-attention">
              {{
                'crops.show.blueprint_summary.attention_suffix'
                  | translate: { count: control.blueprintSummary.attentionCount }
              }}
            </span>
          }
        </p>

        @if (!control.blueprintReadiness.ready) {
          <p class="crop-list-panel__blueprint-hint" role="status">
            {{ 'crops.show.blueprint_summary.setup_required' | translate }}
          </p>
        }

        <div class="crop-list-panel__footer">
          <a
            [routerLink]="['/crops', cropId, 'task_schedule_blueprints']"
            class="btn btn-secondary btn-sm"
          >
            {{ 'crops.index.inline.blueprints_full_edit' | translate }}
          </a>
        </div>
      }
    </div>
  `,
  styleUrls: ['./crop-list-panel.shared.css', './_crop-blueprint-shared.css']
})
export class CropListBlueprintsPanelComponent implements CropListBlueprintsPanelView, OnInit {
  @Input({ required: true }) cropId!: number;

  private readonly loadCropUseCase = inject(LoadCropForEditUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly presenter = inject(CropListBlueprintsPanelPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropListBlueprintsPanelViewState = initialControl;
  get control(): CropListBlueprintsPanelViewState {
    return this._control;
  }
  set control(value: CropListBlueprintsPanelViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadCropUseCase.execute({ cropId: this.cropId });
    this.loadBlueprintsUseCase.execute({ cropId: this.cropId });
  }
}
