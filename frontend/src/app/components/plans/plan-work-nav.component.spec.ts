import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanWorkNavComponent } from './plan-work-nav.component';

describe('PlanWorkNavComponent', () => {
  let fixture: ComponentFixture<PlanWorkNavComponent>;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkNavComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([
          { path: 'plans/:id/work', component: PlanWorkNavComponent },
          { path: 'plans/:id/task_schedule', component: PlanWorkNavComponent },
          { path: 'plans/:id/work_records', component: PlanWorkNavComponent }
        ])
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.work.nav.work': '今日の作業',
      'plans.work.nav.schedule': '全体スケジュール',
      'plans.work.nav.history': '実績履歴'
    });

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(PlanWorkNavComponent);
    fixture.componentInstance.planId = 1;
  });

  it('clips vertical overflow so tab underlines do not show a vertical scrollbar', async () => {
    await router.navigateByUrl('/plans/1/work');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('.plan-work-nav');
    expect(nav).toBeTruthy();
    const styles = getComputedStyle(nav);
    expect(styles.overflowY).toBe('hidden');
    expect(styles.overflowX).toBe('auto');
  });

  it('renders an underline tablist with three work views', async () => {
    await router.navigateByUrl('/plans/1/task_schedule');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('.plan-work-nav');
    expect(nav?.getAttribute('role')).toBe('tablist');

    const links = fixture.nativeElement.querySelectorAll('.plan-work-nav__link');
    expect(links.length).toBe(3);
    expect(fixture.nativeElement.querySelector('.plan-work-nav__link--active')?.textContent).toContain(
      '全体スケジュール'
    );
    expect(links[0].classList.contains('btn-primary')).toBe(false);
    expect(nav?.classList.contains('plan-work-nav--spaced')).toBe(true);
  });

  it('renders Hindi nav tabs instead of ja fallback', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('in', {
      'plans.work.nav.work': 'आज का कार्य',
      'plans.work.nav.schedule': 'पूर्ण अनुसूची',
      'plans.work.nav.history': 'कार्य इतिहास'
    });
    translate.use('in');

    await router.navigateByUrl('/plans/1/work_records');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const navLinks = fixture.nativeElement.querySelectorAll('.plan-work-nav__link');
    expect(navLinks.length).toBe(3);
    expect(navLinks[0].textContent?.trim()).toBe('आज का कार्य');
    expect(navLinks[1].textContent?.trim()).toBe('पूर्ण अनुसूची');
    expect(navLinks[2].textContent?.trim()).toBe('कार्य इतिहास');
  });
});
