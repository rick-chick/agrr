import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { TaskScheduleSyncState } from '../../domain/plans/task-schedule-sync-state';
import {
  buildTaskScheduleSyncBannerViewModel,
  type TaskScheduleSyncBannerViewModel
} from '../../adapters/plans/task-schedule-sync-presenter.helpers';
import type { TaskScheduleSyncCropNames } from '../../domain/plans/task-schedule-sync-error';
import type { PlanWizardReturnTab } from '../../domain/crops/plan-wizard-context';

@Component({
  selector: 'app-task-schedule-sync-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule, RouterLink],
  template: `
    @if (vm.visible) {
      <div [class]="vm.bannerClass" role="status" aria-live="polite">
        @if (vm.showHeadline) {
          <p>{{ vm.messageKey | translate }}</p>
        }
        @if (syncState === 'failed' && vm.syncErrorDetailKey) {
          <p class="task-schedule-sync-banner__detail">
            {{ vm.syncErrorDetailKey | translate: vm.syncErrorDetailParams }}
          </p>
        }
        @if (vm.remediationLinkKey) {
          <div class="task-schedule-sync-banner__wizard-actions">
            <a
              [routerLink]="vm.cropsRouterLink"
              [queryParams]="vm.cropMasterQueryParams"
              class="task-schedule-sync-banner__wizard-cta task-schedule-sync-banner__link--primary"
            >
              {{ vm.remediationLinkKey | translate: vm.remediationLinkParams }}
            </a>
          </div>
        }
        @if (vm.showCropWizardLinks) {
          <div class="task-schedule-sync-banner__wizard-actions" role="list">
            @for (entry of vm.cropBannerEntries; track entry.cropId) {
              <a
                role="listitem"
                [routerLink]="['/crops', entry.cropId, 'task_schedule_blueprints']"
                [queryParams]="vm.cropMasterQueryParams"
                class="task-schedule-sync-banner__wizard-cta task-schedule-sync-banner__crop-link"
              >
                <span class="task-schedule-sync-banner__wizard-cta-label">
                  {{ entry.label }}
                </span>
                <span class="task-schedule-sync-banner__wizard-cta-hint">
                  {{ 'plans.task_schedules.sync_wizard_cta_hint' | translate }}
                </span>
              </a>
            }
          </div>
        }
        @if (regenerateError) {
          <p class="task-schedule-sync-banner__detail">{{ regenerateError | translate }}</p>
        }
        @if (vm.showRetry) {
          <button
            type="button"
            class="btn btn-secondary task-schedule-sync-banner__retry"
            [disabled]="regenerating"
            (click)="retry.emit()"
          >
            {{
              (regenerating ? 'common.loading' : 'plans.task_schedules.sync_retry') | translate
            }}
          </button>
        }
      </div>
    }
  `,
  styleUrls: ['./task-schedule-sync-banner.component.css']
})
export class TaskScheduleSyncBannerComponent {
  @Input({ required: true }) syncState!: TaskScheduleSyncState | string;
  @Input() syncError: string | null = null;
  @Input() cropIds: number[] = [];
  @Input() cropNames: TaskScheduleSyncCropNames = {};
  @Input() planId = 0;
  @Input() returnTab: PlanWizardReturnTab = 'task_schedule';
  @Input() syncErrorCropId: number | null = null;
  @Input() regenerating = false;
  @Input() regenerateError: string | null = null;
  @Output() retry = new EventEmitter<void>();

  private cachedVm: TaskScheduleSyncBannerViewModel | null = null;
  private cachedVmInputsKey: string | null = null;

  get vm(): TaskScheduleSyncBannerViewModel {
    const inputsKey = JSON.stringify({
      syncState: this.syncState,
      syncError: this.syncError,
      cropIds: this.cropIds,
      cropNames: this.cropNames,
      planId: this.planId,
      syncErrorCropId: this.syncErrorCropId,
      regenerateError: this.regenerateError,
      returnTab: this.returnTab
    });
    if (this.cachedVmInputsKey === inputsKey && this.cachedVm != null) {
      return this.cachedVm;
    }
    this.cachedVm = buildTaskScheduleSyncBannerViewModel({
      syncState: this.syncState,
      syncError: this.syncError,
      cropIds: this.cropIds,
      cropNames: this.cropNames,
      planId: this.planId,
      syncErrorCropId: this.syncErrorCropId,
      regenerateError: this.regenerateError,
      returnTab: this.returnTab
    });
    this.cachedVmInputsKey = inputsKey;
    return this.cachedVm;
  }
}
