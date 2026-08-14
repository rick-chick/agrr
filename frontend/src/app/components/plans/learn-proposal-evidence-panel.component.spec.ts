import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';

describe('LearnProposalEvidencePanelComponent', () => {
  let fixture: ComponentFixture<LearnProposalEvidencePanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LearnProposalEvidencePanelComponent, TranslateModule.forRoot()]
    }).compileComponents();

    fixture = TestBed.createComponent(LearnProposalEvidencePanelComponent);
    fixture.componentInstance.toggleLabelKey = 'plans.learn.stage_gdd_calibration.evidence.toggle';
    fixture.componentInstance.rationaleKey = 'plans.learn.stage_gdd_calibration.evidence.rationale';
    fixture.componentInstance.recordsTitleKey =
      'plans.learn.stage_gdd_calibration.evidence.records_title';
    fixture.componentInstance.recordLabelKey = 'plans.learn.stage_gdd_calibration.evidence.record';
    fixture.componentInstance.evidence = {
      exceedanceCount: 2,
      thresholdValue: 10,
      totalRecordedCount: 3,
      contributingRecords: [{ name: 'Transplant', actualDate: '2025-04-10' }]
    };
    fixture.detectChanges();
  });

  it('shows rationale and contributing records after expanding', () => {
    const toggle = fixture.nativeElement.querySelector(
      '.learn-proposal-evidence__toggle'
    ) as HTMLButtonElement;
    expect(fixture.nativeElement.querySelector('.learn-proposal-evidence__panel')).toBeNull();

    toggle.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.learn-proposal-evidence__panel')).not.toBeNull();
    expect(
      fixture.nativeElement.querySelectorAll('.learn-proposal-evidence__record').length
    ).toBe(1);
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
  });
});
