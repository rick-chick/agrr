import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanWorkContextNavComponent } from './plan-work-context-nav.component';

describe('PlanWorkContextNavComponent', () => {
  let fixture: ComponentFixture<PlanWorkContextNavComponent>;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkContextNavComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([
          { path: 'plans/:id', component: PlanWorkContextNavComponent },
          { path: 'plans/:id/task_schedule', component: PlanWorkContextNavComponent },
          { path: 'plans/:id/work', component: PlanWorkContextNavComponent },
          { path: 'plans/:id/work_records', component: PlanWorkContextNavComponent }
        ])
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.work.nav.aria_label': '作業記録ナビゲーション',
      'plans.work.nav.work': '今日の作業',
      'plans.work.nav.history': '実績履歴',
      'plans.show.nav.workbench': '作付け計画',
      'plans.show.nav.task_schedule': '作業予定表'
    });

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(PlanWorkContextNavComponent);
    fixture.componentInstance.planId = 1;
  });

  it('renders plan and work context links with navigation role', async () => {
    await router.navigateByUrl('/plans/1/work');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('.plan-context-nav');
    expect(nav?.getAttribute('role')).toBe('navigation');

    const links = fixture.nativeElement.querySelectorAll('.plan-context-nav__link');
    expect(links.length).toBe(4);
    expect(links[0].textContent?.trim()).toBe('作付け計画');
    expect(links[1].textContent?.trim()).toBe('作業予定表');
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
      '作業予定表'
    );
  });
});
