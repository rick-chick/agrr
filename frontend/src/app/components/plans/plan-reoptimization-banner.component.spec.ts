import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanReoptimizationBannerComponent } from './plan-reoptimization-banner.component';

describe('PlanReoptimizationBannerComponent', () => {
  let fixture: ComponentFixture<PlanReoptimizationBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanReoptimizationBannerComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.show.reoptimization_banner.message': 'Re-optimization recommended',
        'plans.show.reoptimization_banner.hint': 'Drag cultivations on the Gantt.'
      },
      true
    );

    fixture = TestBed.createComponent(PlanReoptimizationBannerComponent);
  });

  it('renders banner content when visible', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-reoptimization-banner')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Re-optimization recommended');
  });
});
