import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  buildPublicPlanPrivateValueFeatures,
  PublicPlanPrivateValuePreviewComponent
} from './public-plan-private-value-preview.component';

describe('buildPublicPlanPrivateValueFeatures', () => {
  it('lists three private-only value features', () => {
    const features = buildPublicPlanPrivateValueFeatures();
    expect(features).toHaveLength(3);
    expect(features.map((f) => f.featureKey)).toEqual([
      'weather_reschedule',
      'learn_loop',
      'work_gdd_comparison'
    ]);
  });
});

describe('PublicPlanPrivateValuePreviewComponent', () => {
  let fixture: ComponentFixture<PublicPlanPrivateValuePreviewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanPrivateValuePreviewComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'public_plans.results.private_value_preview.title': 'ログイン後に使える機能',
        'public_plans.results.private_value_preview.lead': 'マイプランに保存すると利用できます。',
        'public_plans.results.private_value_preview.weather_reschedule.title': '天候リスケ',
        'public_plans.results.private_value_preview.weather_reschedule.description':
          '天候変化に合わせて作付け計画を自動提案',
        'public_plans.results.private_value_preview.learn_loop.title': '学習ループ',
        'public_plans.results.private_value_preview.learn_loop.description':
          '実績と計画の差分から次シーズンを改善',
        'public_plans.results.private_value_preview.work_gdd_comparison.title': '作業 GDD 比較',
        'public_plans.results.private_value_preview.work_gdd_comparison.description':
          '計画と記録の GDD を比較して遅延を把握'
      },
      true
    );

    fixture = TestBed.createComponent(PublicPlanPrivateValuePreviewComponent);
  });

  it('renders private value preview band with three features', () => {
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('ログイン後に使える機能');
    expect(text).toContain('天候リスケ');
    expect(text).toContain('学習ループ');
    expect(text).toContain('作業 GDD 比較');

    const items = fixture.nativeElement.querySelectorAll(
      '.public-plan-private-value-preview__item'
    );
    expect(items).toHaveLength(3);
  });
});
