import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { PublicPlanResultsUpsellComponent } from './public-plan-results-upsell.component';

describe('PublicPlanResultsUpsellComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanResultsUpsellComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();
  });

  it('renders private value preview with three feature cards', () => {
    const fixture = TestBed.createComponent(PublicPlanResultsUpsellComponent);
    fixture.componentInstance.savedPlanId = null;
    fixture.detectChanges();

    const preview = fixture.nativeElement.querySelector('.public-plan-results-upsell__preview');
    expect(preview).toBeTruthy();

    const cards = fixture.nativeElement.querySelectorAll('.public-plan-results-upsell__preview-card');
    expect(cards.length).toBe(3);
  });

  it('renders next steps checklist with three steps', () => {
    const fixture = TestBed.createComponent(PublicPlanResultsUpsellComponent);
    fixture.componentInstance.savedPlanId = null;
    fixture.detectChanges();

    const checklist = fixture.nativeElement.querySelector('.public-plan-results-upsell__next-steps');
    expect(checklist).toBeTruthy();

    const steps = fixture.nativeElement.querySelectorAll('.public-plan-results-upsell__step');
    expect(steps.length).toBe(3);
  });

  it('marks save step complete when savedPlanId is set', () => {
    const fixture = TestBed.createComponent(PublicPlanResultsUpsellComponent);
    fixture.componentInstance.savedPlanId = 42;
    fixture.detectChanges();

    const completedSteps = fixture.nativeElement.querySelectorAll(
      '.public-plan-results-upsell__step--completed'
    );
    expect(completedSteps.length).toBe(1);
    expect(completedSteps[0].textContent).toContain('public_plans.results.next_steps.save.title');
  });

  it('shows post-save links for task schedule and work records when savedPlanId is set', () => {
    const fixture = TestBed.createComponent(PublicPlanResultsUpsellComponent);
    fixture.componentInstance.savedPlanId = 42;
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('a.public-plan-results-upsell__step-cta');
    expect(links.length).toBe(2);
    expect(links[0].getAttribute('href')).toContain('/plans/42/task_schedule');
    expect(links[1].getAttribute('href')).toContain('/plans/42/work_records');
  });

  it('does not show post-save links before save', () => {
    const fixture = TestBed.createComponent(PublicPlanResultsUpsellComponent);
    fixture.componentInstance.savedPlanId = null;
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('a.public-plan-results-upsell__step-cta');
    expect(links.length).toBe(0);
  });
});
