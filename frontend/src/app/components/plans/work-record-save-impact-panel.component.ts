import { Component, EventEmitter, Input, Output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { WorkRecordSaveImpactPanelView } from '../../domain/plans/work-record-save-impact';

@Component({
  selector: 'app-work-record-save-impact-panel',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <aside class="work-record-save-impact" role="status" aria-live="polite">
      <div class="work-record-save-impact__header">
        <h3 class="work-record-save-impact__title">
          {{ 'plans.work.save_impact.title' | translate }}
        </h3>
        <button
          type="button"
          class="work-record-save-impact__dismiss"
          [attr.aria-label]="'common.close' | translate"
          (click)="dismiss.emit()"
        >
          {{ 'common.close' | translate }}
        </button>
      </div>
      <dl class="work-record-save-impact__grid">
        <div class="work-record-save-impact__row">
          <dt>{{ 'plans.work.save_impact.task_variance' | translate }}</dt>
          <dd>
            {{
              'plans.work.save_impact.task_variance_value'
                | translate
                  : {
                      name: panel.taskName,
                      deltaDays: panel.deltaDays,
                      gddDelta: panel.gddDelta
                    }
            }}
          </dd>
        </div>
        <div class="work-record-save-impact__row">
          <dt>{{ 'plans.work.save_impact.unrecorded' | translate }}</dt>
          <dd>{{ panel.unrecordedCount }}</dd>
        </div>
        @if (panel.averageDeltaDays != null) {
          <div class="work-record-save-impact__row">
            <dt>{{ 'plans.work.save_impact.average_delta' | translate }}</dt>
            <dd>{{ panel.averageDeltaDays }}</dd>
          </div>
        }
      </dl>
      <a
        class="work-record-save-impact__learn-link"
        [routerLink]="['/plans', panel.planId, 'learn']"
      >{{ 'plans.work.save_impact.learn_link' | translate }}</a>
    </aside>
  `,
  styleUrls: ['./work-record-save-impact-panel.component.css']
})
export class WorkRecordSaveImpactPanelComponent {
  @Input({ required: true }) panel!: WorkRecordSaveImpactPanelView;
  @Output() dismiss = new EventEmitter<void>();
}
