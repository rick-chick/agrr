import { Component, Input, Output, EventEmitter, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import type { LearnPostMasterContext } from '../../domain/plans/learn-post-master-follow-up';

@Component({
  selector: 'app-learn-post-master-confirmation',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    <section
      class="learn-post-master-confirmation"
      aria-labelledby="learn-post-master-heading"
      role="status"
    >
      <h3 id="learn-post-master-heading" class="learn-post-master-confirmation__title">
        {{ 'plans.learn.post_master.title' | translate }}
      </h3>
      <p class="learn-post-master-confirmation__message">
        {{
          messageKey(context)
            | translate: { crop: context.cropName, detail: displayDetail }
        }}
      </p>
      <div class="learn-post-master-confirmation__actions">
        <a
          class="btn-primary learn-post-master-confirmation__workbench-cta"
          [routerLink]="workbenchLink"
          (click)="confirmed.emit()"
        >
          {{ 'plans.learn.post_master.open_workbench' | translate }}
        </a>
      </div>
    </section>
  `,
  styleUrls: ['./learn-post-master-confirmation.component.css']
})
export class LearnPostMasterConfirmationComponent {
  private readonly translate = inject(TranslateService);

  @Input({ required: true }) planId!: number;
  @Input({ required: true }) context!: LearnPostMasterContext;
  @Output() readonly confirmed = new EventEmitter<void>();

  get workbenchLink(): (string | number)[] {
    return ['/plans', this.planId];
  }

  get displayDetail(): string {
    if (this.context.kind === 'bp_timing') {
      return this.translate.instant(
        `plans.learn.bp_timing_adjustment.category.${this.context.detailLabel}`
      );
    }
    return this.context.detailLabel;
  }

  messageKey(context: LearnPostMasterContext): string {
    return context.kind === 'stage_gdd'
      ? 'plans.learn.post_master.stage_gdd_message'
      : 'plans.learn.post_master.bp_timing_message';
  }
}
