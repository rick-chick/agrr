import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { PlanCreateReadinessSummaryComponent } from './plan-create-readiness-summary.component';
import { buildPlanCreateReadiness } from '../../domain/plans/plan-create-readiness';

describe('PlanCreateReadinessSummaryComponent', () => {
  let fixture: ComponentFixture<PlanCreateReadinessSummaryComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanCreateReadinessSummaryComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanCreateReadinessSummaryComponent);
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'plans.new.readiness.title': 'Setup readiness',
      'plans.new.readiness.fields_ready': 'Fields registered ({{count}})',
      'plans.new.readiness.fields_missing': 'No fields',
      'plans.new.readiness.fields_action': 'Register fields',
      'plans.new.readiness.weather_ready': 'Weather ready',
      'plans.new.readiness.weather_missing': 'Weather missing',
      'plans.new.readiness.weather_action': 'Check weather',
      'plans.new.readiness.crops_missing': 'No crops',
      'plans.new.readiness.crops_action': 'Set up crops',
      'models.farm.weather_status.pending': 'Pending'
    });
    translate.use('en');
  });

  it('renders deep links for incomplete readiness items', () => {
    fixture.componentInstance.readiness = buildPlanCreateReadiness({
      farmId: 7,
      fieldCount: 0,
      hasValidFields: false,
      weatherStatus: 'pending',
      crops: [],
      cropBlueprints: {}
    });
    fixture.detectChanges();

    const links = Array.from(
      fixture.nativeElement.querySelectorAll('a.blueprint-readiness__link')
    ) as HTMLAnchorElement[];
    expect(links.map((link) => link.getAttribute('href'))).toEqual(['/farms/7', '/farms/7', '/crops/new']);
  });
});
