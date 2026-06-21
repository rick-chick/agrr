import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkRecordsComponent } from './plan-work-records.component';
import { PlanWorkRecordsViewState } from './plan-work-records.view';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';

describe('PlanWorkRecordsComponent', () => {
  let component: PlanWorkRecordsComponent;
  let fixture: ComponentFixture<PlanWorkRecordsComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanWorkRecordsComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkRecordsUseCase, useValue: loadUseCase },
          { provide: PlanWorkRecordsPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: { paramMap: { get: vi.fn(() => '7') } }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkRecordsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanWorkRecordsComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.work.back_to_plan': 'Back to plan',
        'plans.work_records.title': 'Work history — {{name}}',
        'plans.work_records.empty': 'No work records yet',
        'plans.work_records.badge.from_schedule': 'From schedule',
        'plans.work_records.badge.adhoc': 'Ad hoc',
        'common.api_error.generic': 'An error occurred'
      },
      true
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('implements View control getter/setter', () => {
    const state: PlanWorkRecordsViewState = {
      loading: false,
      error: null,
      plan: null,
      groups: []
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('renders grouped work records when data is loaded', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: 5,
              agricultural_task_id: null,
              name: 'Weeding',
              task_type: null,
              actual_date: '2026-06-12',
              amount: null,
              amount_unit: null,
              time_spent_minutes: null,
              notes: null,
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: null
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Work history');
    expect(text).toContain('Weeding');
    expect(text).toContain('From schedule');
    expect(text).not.toContain('No work records yet');
  });

  it('renders translated API error instead of raw i18n key', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      plan: null,
      groups: []
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('An error occurred');
    expect(text).not.toContain('common.api_error.generic');
  });

  it('loads records on init when planId is valid', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });
});
