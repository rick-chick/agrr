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
          { path: 'plans/:id/task_schedule', component: PlanDetailContextNavComponent },
          { path: 'plans/:id/work', component: PlanDetailContextNavComponent },
          { path: 'plans/:id/work_records', component: PlanDetailContextNavComponent }
        ])
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.show.nav.aria_label': '計画画面ナビゲーション',
      'plans.show.nav.workbench': '作付け計画',
      'plans.show.nav.task_schedule': '作業計画表',
      'plans.work.nav.work': '今日の作業',
      'plans.work.nav.history': '実績履歴'
    });

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(PlanDetailContextNavComponent);
    fixture.componentInstance.planId = 1;
  });

  it('renders four plan context tabs with navigation role', async () => {
    await router.navigateByUrl('/plans/1/work');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('.plan-context-nav');
    expect(nav?.getAttribute('role')).toBe('navigation');
    expect(nav?.getAttribute('aria-label')).toBe('計画画面ナビゲーション');

    const links = fixture.nativeElement.querySelectorAll('.plan-context-nav__link');
    expect(links.length).toBe(4);
    expect(links[0].textContent?.trim()).toBe('作付け計画');
    expect(links[1].textContent?.trim()).toBe('作業計画表');
    expect(links[2].textContent?.trim()).toBe('今日の作業');
    expect(links[3].textContent?.trim()).toBe('実績履歴');
    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '今日の作業'
    );
  });

  it('marks workbench link active on plan detail route', async () => {
    await router.navigateByUrl('/plans/1');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '作付け計画'
    );
  });

  it('marks task schedule link active on task schedule route', async () => {
    await router.navigateByUrl('/plans/1/task_schedule');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '作業計画表'
    );
  });

  it('marks history link active on work records route', async () => {
    await router.navigateByUrl('/plans/1/work_records');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '実績履歴'
    );
  });
});
