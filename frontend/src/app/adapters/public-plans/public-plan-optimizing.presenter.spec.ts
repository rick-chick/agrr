import { TestBed } from '@angular/core/testing';
import { TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PublicPlanOptimizingPresenter } from './public-plan-optimizing.presenter';
import {
  PublicPlanOptimizingView,
  PublicPlanOptimizingViewState
} from '../../components/public-plans/public-plan-optimizing.view';
import { UxAnalyticsService } from '../../services/ux-analytics.service';

const translationMap = new Map<string, string>([
  ['models.cultivation_plan.phases.completed', '最適化が完了しました'],
  ['models.cultivation_plan.phases.optimizing', '最適化処理中...'],
  [
    'models.cultivation_plan.phase_failed.predicting_weather',
    '気象データの予測に失敗しました'
  ],
  [
    'models.cultivation_plan.phase_failed.fetching_weather',
    '気象データの取得に失敗しました'
  ],
  ['models.cultivation_plan.phase_failed.default', '処理に失敗しました'],
  ['models.cultivation_plan.phase_failed.timeout', '処理がタイムアウトしました'],
  ['public_plans.optimizing.error.connection_lost', '接続が切断されました。しばらくしてからやり直してください。'],
  [
    'public_plans.optimizing.error.hints.predicting_weather',
    '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。'
  ],
  [
    'public_plans.optimizing.error.hints.fetching_weather',
    '地域や農場の設定を確認し、しばらく時間をおいてから再度お試しください。'
  ],
  [
    'public_plans.optimizing.error.hints.timeout',
    '処理に時間がかかりすぎました。しばらく待ってから再度お試しください。'
  ],
  [
    'public_plans.optimizing.error.hints.default',
    '下のボタンから作物を変更するか、最初からやり直してください。'
  ],
  [
    'models.cultivation_plan.phase_failed.task_schedule_generation',
    '作業計画の生成に失敗しました'
  ],
  [
    'models.cultivation_plan.phase_failed.optimizing',
    '最適化に失敗しました'
  ],
  [
    'public_plans.optimizing.error.hints.task_schedule_generation',
    '最適化結果の処理中に問題が発生しました。再度お試しください。'
  ],
  [
    'public_plans.optimizing.error.hints.optimizing',
    '作物と栽培期間を確認してから、もう一度お試しください。'
  ]
]);

describe('PublicPlanOptimizingPresenter', () => {
  let presenter: PublicPlanOptimizingPresenter;
  let lastControl: PublicPlanOptimizingViewState;
  let onCompletedSpy: ReturnType<typeof vi.fn<() => void>>;
  let view: PublicPlanOptimizingView;
  let uxAnalytics: { trackOptimizationLifecycle: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    uxAnalytics = { trackOptimizationLifecycle: vi.fn() };
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
        },
        { provide: UxAnalyticsService, useValue: uxAnalytics }
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
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'completed',
      flow: 'public_plans',
      job_scenario: 'J3'
    });
  });

  it('uses phase_failed message when status is failed', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.predicting_weather'
    });

    expect(lastControl.status).toBe('failed');
    expect(lastControl.phaseMessage).toBe('気象データの予測に失敗しました');
    expect(lastControl.failureCategory).toBe('predicting_weather');
    expect(onCompletedSpy).not.toHaveBeenCalled();
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'predicting_weather'
    });
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

  it('uses i18n default category instead of raw phase_message text', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: '気象データの予測に失敗しました'
    });

    expect(lastControl.phaseMessage).toBe('処理に失敗しました');
    expect(lastControl.phaseMessage).not.toBe('気象データの予測に失敗しました');
    expect(lastControl.failureHint).toBe(
      '下のボタンから作物を変更するか、最初からやり直してください。'
    );
  });

  it('does not surface technical phase_message as primary failure text', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'fetch_weather_data failed: InvalidWeatherApiResponse'
    });

    expect(lastControl.phaseMessage).toBe('気象データの取得に失敗しました');
    expect(lastControl.phaseMessage).not.toContain('InvalidWeatherApiResponse');
    expect(lastControl.failureHint).toBe(
      '地域や農場の設定を確認し、しばらく時間をおいてから再度お試しください。'
    );
  });

  it('resolves timeout category from message_key', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.timeout'
    });

    expect(lastControl.phaseMessage).toBe('処理がタイムアウトしました');
    expect(lastControl.failureHint).toBe(
      '処理に時間がかかりすぎました。しばらく待ってから再度お試しください。'
    );
  });

  it('infers task_schedule_generation category from technical phase_message', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'task_schedule_generation worker exited with code 1'
    });

    expect(lastControl.phaseMessage).toBe('作業計画の生成に失敗しました');
    expect(lastControl.failureHint).toBe(
      '最適化結果の処理中に問題が発生しました。再度お試しください。'
    );
    expect(lastControl.failureCategory).toBe('task_schedule_generation');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'task_schedule_generation'
    });
  });

  it('infers optimizing category from technical phase_message', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'allocate optimizer failed: infeasible constraints'
    });

    expect(lastControl.phaseMessage).toBe('最適化に失敗しました');
    expect(lastControl.failureHint).toBe('作物と栽培期間を確認してから、もう一度お試しください。');
    expect(lastControl.failureCategory).toBe('optimizing');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'optimizing'
    });
  });

  it('infers timeout category from technical phase_message', () => {
    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'worker timeout after 120s'
    });

    expect(lastControl.phaseMessage).toBe('処理がタイムアウトしました');
    expect(lastControl.failureHint).toBe(
      '処理に時間がかかりすぎました。しばらく待ってから再度お試しください。'
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

  it('sets failed state with connection lost message on presentConnectionLost', () => {
    presenter.presentConnectionLost();

    expect(lastControl.status).toBe('failed');
    expect(lastControl.phaseMessage).toContain('接続が切断されました');
    expect(lastControl.failureHint).toBe(
      '下のボタンから作物を変更するか、最初からやり直してください。'
    );
    expect(lastControl.failureCategory).toBe('connection_lost');
    expect(onCompletedSpy).not.toHaveBeenCalled();
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'public_plans',
      job_scenario: 'J3',
      failure_category: 'connection_lost'
    });
  });

  it('ignores stale failed messages after optimization completed', () => {
    presenter.present({
      status: 'completed',
      progress: 100,
      message_key: 'models.cultivation_plan.phases.completed'
    });

    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.predicting_weather'
    });

    expect(lastControl.status).toBe('completed');
    expect(lastControl.progress).toBe(100);
    expect(lastControl.phaseMessage).toBe('最適化が完了しました');
    expect(onCompletedSpy).toHaveBeenCalledTimes(1);
  });

  it('ignores connection lost after optimization completed', () => {
    presenter.present({
      status: 'completed',
      progress: 100,
      message_key: 'models.cultivation_plan.phases.completed'
    });

    presenter.presentConnectionLost();

    expect(lastControl.status).toBe('completed');
    expect(lastControl.progress).toBe(100);
    expect(lastControl.phaseMessage).toBe('最適化が完了しました');
    expect(onCompletedSpy).toHaveBeenCalledTimes(1);
  });

  it('ignores connection lost when progress already reached 100', () => {
    presenter.present({
      status: 'optimizing',
      progress: 100,
      message_key: 'models.cultivation_plan.phases.optimizing'
    });

    presenter.presentConnectionLost();

    expect(lastControl.status).toBe('optimizing');
    expect(lastControl.progress).toBe(100);
    expect(onCompletedSpy).not.toHaveBeenCalled();
  });

  it('ignores stale failed messages when progress already reached 100', () => {
    presenter.present({
      status: 'optimizing',
      progress: 100,
      message_key: 'models.cultivation_plan.phases.optimizing'
    });

    presenter.present({
      status: 'failed',
      progress: 0,
      message_key: 'models.cultivation_plan.phase_failed.predicting_weather'
    });

    expect(lastControl.status).toBe('optimizing');
    expect(lastControl.progress).toBe(100);
    expect(lastControl.phaseMessage).toBe('最適化処理中...');
    expect(onCompletedSpy).not.toHaveBeenCalled();
  });
});
