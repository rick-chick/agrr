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
      'plans.work.nav.history': '実績履歴'
    });

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(PlanWorkContextNavComponent);
    fixture.componentInstance.planId = 1;
  });

  it('renders two work-log context links with navigation role', async () => {
    await router.navigateByUrl('/plans/1/work');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const nav = fixture.nativeElement.querySelector('.plan-context-nav');
    expect(nav?.getAttribute('role')).toBe('navigation');

    const links = fixture.nativeElement.querySelectorAll('.plan-context-nav__link');
    expect(links.length).toBe(2);
    expect(links[0].textContent?.trim()).toBe('今日の作業');
    expect(links[1].textContent?.trim()).toBe('実績履歴');
    expect(fixture.nativeElement.querySelector('.plan-context-nav__link--active')?.textContent).toContain(
      '今日の作業'
    );
  });
});
