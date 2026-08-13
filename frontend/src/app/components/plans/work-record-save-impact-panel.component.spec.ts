import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { WorkRecordSaveImpactPanelComponent } from './work-record-save-impact-panel.component';

describe('WorkRecordSaveImpactPanelComponent', () => {
  let fixture: ComponentFixture<WorkRecordSaveImpactPanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WorkRecordSaveImpactPanelComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.work.save_impact.title': 'Plan impact',
        'plans.work.save_impact.task_label': 'Task',
        'plans.work.save_impact.delta_days': 'Days',
        'plans.work.save_impact.gdd_delta': 'GDD',
        'plans.work.save_impact.unrecorded': 'Unrecorded',
        'plans.work.save_impact.average_delta': 'Avg delta',
        'plans.work.save_impact.learn_link': 'Review in Learn',
        'plans.work.save_impact.workbench_link': 'Review adjust on workbench',
        'plans.work.save_impact.dismiss': 'Dismiss'
      },
      true
    );

    fixture = TestBed.createComponent(WorkRecordSaveImpactPanelComponent);
    fixture.componentInstance.planId = 7;
    fixture.componentInstance.impact = {
      taskName: 'Weeding',
      deltaDays: '+3',
      gddDelta: '+30.5',
      planStats: {
        completedCount: 3,
        averageDeltaDays: 2.5,
        unrecordedCount: 4
      },
      workbenchFieldCultivationId: null
    };
  });

  it('renders task variance and plan summary with learn link', () => {
    fixture.detectChanges();
    const element = fixture.nativeElement as HTMLElement;
    expect(element.textContent).toContain('Weeding');
    expect(element.textContent).toContain('+3');
    expect(element.textContent).toContain('+30.5');
    expect(element.textContent).toContain('4');
    expect(element.textContent).toContain('+2.5');
    const learnLink = element.querySelector('.work-record-save-impact__learn-link') as HTMLAnchorElement;
    expect(learnLink.getAttribute('href')).toBe('/plans/7/learn');
  });

  it('renders workbench deep link when threshold action is required', () => {
    fixture.componentInstance.impact = {
      taskName: 'Weeding',
      deltaDays: '+3',
      gddDelta: '+30.5',
      planStats: {
        completedCount: 3,
        averageDeltaDays: 2.5,
        unrecordedCount: 4
      },
      workbenchFieldCultivationId: 10
    };
    fixture.detectChanges();

    const workbenchLink = fixture.nativeElement.querySelector(
      '.work-record-save-impact__workbench-link'
    ) as HTMLAnchorElement;
    expect(workbenchLink.textContent).toContain('Review adjust on workbench');
    expect(workbenchLink.getAttribute('href')).toContain('field_cultivation_id=10');
  });
});
