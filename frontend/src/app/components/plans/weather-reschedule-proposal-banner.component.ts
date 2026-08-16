import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { computeWeatherRescheduleDelayDays } from '../../domain/plans/compute-weather-reschedule-delay-days';
import { mapWeatherProposalToAttentionTrigger } from '../../domain/plans/map-weather-proposals-to-attention-triggers';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import type { WeatherRescheduleProposalPreview } from '../../domain/plans/weather-reschedule-proposal-preview';

@Component({
  selector: 'app-weather-reschedule-proposal-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (proposal) {
      <section
        class="weather-reschedule-proposal-banner"
        role="region"
        aria-labelledby="weather-reschedule-proposal-banner-title"
      >
        <h2 id="weather-reschedule-proposal-banner-title" class="weather-reschedule-proposal-banner__title">
          {{ 'plans.show.weather_reschedule_proposal.title' | translate }}
        </h2>
        <p class="weather-reschedule-proposal-banner__meta">
          {{
            'plans.work.today_attention.weather_trigger.' + proposal.trigger_type | translate
          }}
        </p>
        <p class="weather-reschedule-proposal-banner__meta">
          {{
            'plans.work.today_attention.weather_target'
              | translate: { field: targetFieldName, crop: targetCropName }
          }}
        </p>
        <p class="weather-reschedule-proposal-banner__meta">
          {{ rationaleKey | translate: rationaleParams }}
        </p>
        @if (delayDays != null) {
          <p class="weather-reschedule-proposal-banner__delay">
            {{
              'plans.show.weather_reschedule_proposal.delay_days'
                | translate: { days: delayDays }
            }}
          </p>
        }
        @if (previewLoading) {
          <p class="weather-reschedule-proposal-banner__loading master-loading">
            {{ 'plans.show.weather_reschedule_proposal.preview_loading' | translate }}
          </p>
        }
        @if (previewError) {
          <p class="weather-reschedule-proposal-banner__error" role="alert">
            {{ previewError | translate }}
          </p>
        }
        @if (applyError) {
          <p class="weather-reschedule-proposal-banner__error" role="alert">
            {{ applyError | translate }}
          </p>
        }
        <div class="weather-reschedule-proposal-banner__actions">
          <button
            type="button"
            class="action-button action-button--primary"
            [disabled]="!canApprove"
            (click)="approve.emit()"
          >
            {{ 'plans.show.weather_reschedule_proposal.approve' | translate }}
          </button>
          <button
            type="button"
            class="action-button action-button--secondary"
            [disabled]="applyLoading"
            (click)="reject.emit()"
          >
            {{ 'plans.show.weather_reschedule_proposal.reject' | translate }}
          </button>
        </div>
      </section>
    }
  `,
  styleUrls: ['./weather-reschedule-proposal-banner.component.css']
})
export class WeatherRescheduleProposalBannerComponent {
  @Input() proposal: WeatherRescheduleProposal | null = null;
  @Input() preview: WeatherRescheduleProposalPreview | null = null;
  @Input() previewLoading = false;
  @Input() previewError: string | null = null;
  @Input() applyLoading = false;
  @Input() applyError: string | null = null;
  @Output() approve = new EventEmitter<void>();
  @Output() reject = new EventEmitter<void>();

  get targetFieldName(): string {
    return this.proposal?.rationale.target_cultivation?.field_name ?? '';
  }

  get targetCropName(): string {
    return this.proposal?.rationale.target_cultivation?.crop_name ?? '';
  }

  get rationaleKey(): string {
    if (!this.proposal) {
      return '';
    }
    return mapWeatherProposalToAttentionTrigger(this.proposal).rationaleI18nKey;
  }

  get rationaleParams(): Record<string, string | number> {
    if (!this.proposal) {
      return {};
    }
    return mapWeatherProposalToAttentionTrigger(this.proposal).rationaleI18nParams;
  }

  get delayDays(): number | null {
    if (!this.proposal) {
      return null;
    }
    const moves = this.preview?.moves ?? this.proposal.moves;
    const startDate = this.proposal.rationale.target_cultivation?.start_date;
    if (!startDate || !Array.isArray(moves)) {
      return null;
    }
    return computeWeatherRescheduleDelayDays(
      startDate,
      moves as { allocation_id: number; action: 'move'; to_field_id: number; to_start_date: string }[]
    );
  }

  get canApprove(): boolean {
    return (
      !this.previewLoading &&
      !this.applyLoading &&
      this.preview != null &&
      (this.preview.moves?.length ?? 0) > 0
    );
  }
}
