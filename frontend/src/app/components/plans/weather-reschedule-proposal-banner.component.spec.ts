import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { WeatherRescheduleProposalBannerComponent } from './weather-reschedule-proposal-banner.component';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';

const proposal: WeatherRescheduleProposal = {
  id: 'frost_forecast:42:0',
  trigger_type: 'frost_forecast',
  severity: 'high',
  rationale: {
    target_cultivation: {
      field_name: '北圃場',
      crop_name: 'トマト',
      start_date: '2026-04-01'
    },
    forecast_t_min: -2,
    frost_threshold: 0
  },
  moves: [
    {
      allocation_id: 42,
      action: 'move',
      to_field_id: 1,
      to_start_date: '2026-04-11'
    }
  ]
};

describe('WeatherRescheduleProposalBannerComponent', () => {
  let fixture: ComponentFixture<WeatherRescheduleProposalBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WeatherRescheduleProposalBannerComponent, TranslateModule.forRoot()]
    }).compileComponents();
    fixture = TestBed.createComponent(WeatherRescheduleProposalBannerComponent);
  });

  it('renders trigger type, target cultivation, rationale, and delay days', () => {
    fixture.componentInstance.proposal = proposal;
    fixture.componentInstance.preview = {
      proposal_id: proposal.id,
      proposal,
      moves: proposal.moves as never[],
      before: { field_schedules: [] },
      after: { field_schedules: [] }
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('plans.show.weather_reschedule_proposal.title');
    expect(text).toContain('plans.work.today_attention.weather_trigger.frost_forecast');
    expect(text).toContain('plans.work.today_attention.weather_target');
    expect(text).toContain('plans.work.today_attention.weather_rationale.frost_forecast');
    expect(fixture.nativeElement.querySelector('.weather-reschedule-proposal-banner__delay')).toBeTruthy();
  });

  it('disables approve until preview is loaded', () => {
    fixture.componentInstance.proposal = proposal;
    fixture.detectChanges();
    const approveButton: HTMLButtonElement | null =
      fixture.nativeElement.querySelector('.action-button--primary');
    expect(approveButton?.disabled).toBe(true);
  });
});
