import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanDetailContextNavComponent } from './plan-detail-context-nav.component';

describe('PlanDetailContextNavComponent', () => {
  let fixture: ComponentFixture<PlanDetailContextNavComponent>;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanDetailContextNavComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([
          { path: 'plans/:id', component: PlanDetailContextNavComponent },
          { path: 'plans/:id/task_schedule', component: PlanDetailContextNavComponent }
        ])
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.show.nav.aria_label': '計画画面ナビゲーション',
      'plans.show.nav.workbench': '作付け計画',
      'plans.show.nav.task_schedule': '作業予定表'
    });

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(PlanDetailContextNavComponent);
    fixture.componentInstance.planId = 1;
  });

  it('renders workbench and task schedule links', async () => {
    await router.navigateByUrl('/plans/1/task_schedule');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('.plan-context-nav__link');
    expect(links.length).toBe(2);
    expect(links[0].textContent?.trim()).toBe('作付け計画');
    expect(links[1].textContent?.trim()).toBe('作業予定表');
    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '作業予定表'
    );
  });
});
