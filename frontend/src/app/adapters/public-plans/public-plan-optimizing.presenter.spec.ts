import { TestBed } from '@angular/core/testing';
import { TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PublicPlanOptimizingPresenter } from './public-plan-optimizing.presenter';
import {
  PublicPlanOptimizingView,
  PublicPlanOptimizingViewState
} from '../../components/public-plans/public-plan-optimizing.view';

const translationMap = new Map<string, string>([
  ['models.cultivation_plan.phases.completed', '最適化が完了しました'],
  ['models.cultivation_plan.phases.optimizing', '最適化処理中...'],
  [
    'models.cultivation_plan.phase_failed.predicting_weather',
    '気象データの予測に失敗しました'
  ],
  ['models.cultivation_plan.phase_failed.default', '処理に失敗しました'],
  ['public_plans.optimizing.error.title', '計画作成に失敗しました'],
  [
    'public_plans.optimizing.error.hints.predicting_weather',
    '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。'
  ],
  [
    'public_plans.optimizing.error.hints.default',
    '下のボタンから作物を変更するか、最初からやり直してください。'
  ]
]);

describe('PublicPlanOptimizingPresenter', () => {
  let presenter: PublicPlanOptimizingPresenter;
  let lastControl: PublicPlanOptimizingViewState;
  let onCompletedSpy: ReturnType<typeof vi.fn<() => void>>;
  let view: PublicPlanOptimizingView;

  beforeEach(() => {
    onCompletedSpy = vi.fn<() => void>();
    lastControl = { status: 'pending', progress: 0, phaseMessage: '' };
    view = {
      get control(): PublicPlanOptimizingViewState {
        return lastControl;
      },
      set control(value: PublicPlanOptimizingViewState) {
        lastControl = value;
      },
      onOptimizationCompleted: () => {
        onCompletedSpy();
      }
    };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        PublicPlanOptimizingPresenter,
        {
          provide: TranslateService,
          useValue: {
            instant: vi.fn((key: string) => translationMap.get(key) ?? key)
          }
        }
      ]
    });

    presenter = TestBed.inject(PublicPlanOptimizingPresenter);
    presenter.setView(view);
  });

  it('resolves message_key for in-progress optimization', () => {
    presenter.present({
      status: 'optimizing',
      progress: 40,
      message_key: 'models.cultivation_plan.phases.optimizing'
    });

    expect(lastControl.status).toBe('optimizing');
    expect(lastControl.progress).toBe(40);
    expect(lastControl.phaseMessage).toBe('最適化処理中...');
    expect(onCompletedSpy).not.toHaveBeenCalled();
  });

  it('navigates hook on completed status', () => {
    presenter.present({
      status: 'completed',
      progress: 100,
      message_key: 'models.cultivation_plan.phases.completed'
    });

    expect(lastControl.status).toBe('completed');
    expect(lastControl.phaseMessage).toBe('最適化が完了しました');
    expect(onCompletedSpy).toHaveBeenCalledTimes(1);
  });

  it('uses phase_failed message when status is failed', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.predicting_weather'
    });

    expect(lastControl.status).toBe('failed');
    expect(lastControl.phaseMessage).toBe('気象データの予測に失敗しました');
    expect(onCompletedSpy).not.toHaveBeenCalled();
  });

  it('does not surface raw models.* keys when failed with phases.completed key', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phases.completed',
      phase_message: 'models.cultivation_plan.phases.completed'
    });

    expect(lastControl.status).toBe('failed');
    expect(lastControl.phaseMessage).toBe('処理に失敗しました');
    expect(lastControl.phaseMessage).not.toContain('models.');
    expect(onCompletedSpy).not.toHaveBeenCalled();
  });

  it('falls back to default failed message when translation is missing', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.unknown_phase'
    });

    expect(lastControl.phaseMessage).toBe('処理に失敗しました');
    expect(lastControl.phaseMessage).not.toMatch(/^models\./);
  });

  it('prefers human-readable phase_message over generic default message_key', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: '気象データの予測に失敗しました'
    });

    expect(lastControl.phaseMessage).toBe('気象データの予測に失敗しました');
    expect(lastControl.failureHint).toBe(
      '下のボタンから作物を変更するか、最初からやり直してください。'
    );
  });

  it('sets category-specific failure hint for known failure keys', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.predicting_weather'
    });

    expect(lastControl.phaseMessage).toBe('気象データの予測に失敗しました');
    expect(lastControl.failureHint).toBe(
      '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。'
    );
  });
});
