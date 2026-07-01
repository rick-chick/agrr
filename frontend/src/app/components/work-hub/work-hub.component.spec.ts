import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkHubComponent } from './work-hub.component';
import { WorkHubInitUseCase } from '../../usecase/work-hub/work-hub-init.usecase';
import { EnsurePlanForFarmUseCase } from '../../usecase/work-hub/ensure-plan-for-farm.usecase';
import { WorkHubPresenter } from '../../adapters/work-hub/work-hub.presenter';

describe('WorkHubComponent', () => {
  let fixture: ComponentFixture<WorkHubComponent>;
  let component: WorkHubComponent;
  let initExecute: ReturnType<typeof vi.fn>;
  let ensureExecute: ReturnType<typeof vi.fn>;
  let mockPresenter: WorkHubPresenter & {
    setView: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    initExecute = vi.fn();
    ensureExecute = vi.fn();
    mockPresenter = {
      setView: vi.fn(),
      present: vi.fn(),
      onError: vi.fn(),
      onSuccess: vi.fn()
    } as unknown as WorkHubPresenter & {
      setView: ReturnType<typeof vi.fn>;
    };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(WorkHubComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: WorkHubInitUseCase, useValue: { execute: initExecute } },
          { provide: EnsurePlanForFarmUseCase, useValue: { execute: ensureExecute } },
          { provide: WorkHubPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [WorkHubComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(WorkHubComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'work.hub.no_farms': '農場がまだ登録されていません',
      'work.hub.select_farm': '農場を選択',
      'work.hub.no_fields_warning': '有効な圃場がありません',
      'work.hub.creating_plan': '計画を準備しています…',
      'work.hub.creating_plan_for': '「{{name}}」の計画を準備しています…',
      'work.hub.subtitle': '農場を選んで今日の作業を記録します',
      'work.hub.error_subtitle': '農場一覧を読み込めませんでした',
      'work.hub.retry': '再読み込み',
      'common.api_error.generic': 'エラーが発生しました'
    });
  });

  it('loads hub data on init', () => {
    fixture.detectChanges();
    expect(initExecute).toHaveBeenCalled();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('shows empty state when no farms are returned', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('農場がまだ登録されていません');
  });

  it('shows farm picker when multiple farms exist', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: null
        }
      ],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(2);
  });

  it('ensures plan when a farm is selected', () => {
    fixture.detectChanges();
    component.selectFarm({
      farmId: 3,
      farmName: 'Farm C',
      fieldCount: 1,
      totalArea: 40,
      hasValidFields: true,
      planId: null
    });
    expect(component.control.submitting).toBe(true);
    expect(ensureExecute).toHaveBeenCalledWith({ farmId: 3, existingPlanId: null });
  });

  it('shows farm picker when a single farm exists', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        }
      ],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
  });

  it('shows field warning for a single farm without valid fields', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 0,
          totalArea: 0,
          hasValidFields: false,
          planId: null
        }
      ],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('有効な圃場がありません');
    expect(fixture.nativeElement.querySelector('.work-hub__farm-btn')?.disabled).toBe(true);
  });

  it('shows creating plan message while submitting and keeps farm list visible', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: true,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: null
        }
      ],
      pendingSuccessFlash: null
    };
    component.selectedFarmName = 'Farm Solo';
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('「Farm Solo」の計画を準備しています…');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
    expect(fixture.nativeElement.querySelector('.page-description')?.textContent).toContain(
      '農場を選んで今日の作業を記録します'
    );
  });

  it('shows error subtitle instead of default subtitle when load fails', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: 'common.api_error.generic',
      farms: [],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    const description = fixture.nativeElement.querySelector('.page-description');
    expect(description?.textContent).toContain('農場一覧を読み込めませんでした');
    expect(description?.textContent).not.toContain('農場を選んで今日の作業を記録します');
  });

  it('shows error with retry and keeps farm list visible', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: 'common.api_error.generic',
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: null
        }
      ],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('エラーが発生しました');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('再読み込み');
  });

  it('reloads hub data when retry is clicked', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      submitting: false,
      error: 'common.api_error.generic',
      farms: [],
      pendingSuccessFlash: null
    };
    fixture.detectChanges();

    initExecute.mockClear();
    fixture.nativeElement.querySelector('.work-hub__retry')?.click();

    expect(initExecute).toHaveBeenCalled();
  });
});
