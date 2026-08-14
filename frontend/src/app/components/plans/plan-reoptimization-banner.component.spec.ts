import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanReoptimizationBannerComponent } from './plan-reoptimization-banner.component';

describe('PlanReoptimizationBannerComponent', () => {
  let fixture: ComponentFixture<PlanReoptimizationBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanReoptimizationBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.show.reoptimization_banner.message': 'Re-optimization recommended',
        'plans.show.reoptimization_banner.hint': 'Drag cultivations on the Gantt.',
        'plans.task_schedules.orchestration.return_to_learn': 'Return to learning screen'
      },
      true
    );

    fixture = TestBed.createComponent(PlanReoptimizationBannerComponent);
    fixture.componentInstance.planId = 4;
  });

  it('renders banner content when visible', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-reoptimization-banner')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Re-optimization recommended');
  });

  it('renders learn loop progress strip during reorganize', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('app-plan-learn-loop-progress-strip')
    ).not.toBeNull();
  });

  it('shows return-to-learn link during reorganize', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.plan-reoptimization-banner__learn-link');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('/plans/4/learn');
    expect(link.textContent).toContain('Return to learning screen');
  });
});
