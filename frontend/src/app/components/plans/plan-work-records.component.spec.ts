import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { BehaviorSubject } from 'rxjs';
import { PlanWorkRecordsComponent } from './plan-work-records.component';
import { PlanWorkRecordsViewState } from './plan-work-records.view';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { emptyPlanSaveImpactViewFields } from '../../adapters/plans/plan-save-impact.presenter.helpers';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import {
  WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO,
  WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_HISTORY,
  WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY,
  WORK_RECORD_PHOTO_THUMB_WIDTH_PX_HISTORY
} from '../../domain/plans/work-record-photo.constants';

const SAVE_IMPACT_DEFAULTS = {
  ...emptyPlanSaveImpactViewFields
};

function createPlanRouteMock(planId: string) {
  let currentPlanId = planId;
  const paramMapSubject = new BehaviorSubject({
    get: (key: string) => (key === 'id' ? currentPlanId : null)
  });
  const queryParamMapSubject = new BehaviorSubject({
    get: () => null
  });

  return {
    snapshot: {
      get paramMap() {
        return paramMapSubject.value;
      },
      queryParamMap: { get: () => null }
    },
    paramMap: paramMapSubject.asObservable(),
    queryParamMap: queryParamMapSubject.asObservable(),
    setPlanId(id: string) {
      currentPlanId = id;
      paramMapSubject.next({
        get: (key: string) => (key === 'id' ? currentPlanId : null)
      });
    }
  };
}

describe('PlanWorkRecordsComponent', () => {
  let component: PlanWorkRecordsComponent;
  let fixture: ComponentFixture<PlanWorkRecordsComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadSummaryUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: {
    setView: ReturnType<typeof vi.fn>;
    queueSaveImpactAfterSave: ReturnType<typeof vi.fn>;
    dismissSaveImpact: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  let mockActivatedRoute: ReturnType<typeof createPlanRouteMock>;

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    loadSummaryUseCase = { execute: vi.fn() };
    mockPresenter = {
      setView: vi.fn(),
      queueSaveImpactAfterSave: vi.fn(() => 1),
      dismissSaveImpact: vi.fn()
    };
    cdr = { markForCheck: vi.fn() };
    mockActivatedRoute = createPlanRouteMock('7');
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    TestBed.overrideComponent(PlanWorkRecordsComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkRecordsUseCase, useValue: loadUseCase },
          { provide: LoadPlanVsActualSummaryUseCase, useValue: loadSummaryUseCase },
          { provide: PlanWorkRecordsPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: mockActivatedRoute
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
        'plans.work.page_title': 'Work log — {{name}}',
        'plans.work_records.empty': 'No work records yet',
        'plans.work_records.empty_hint': 'Record unscheduled work from the Today\'s work tab',
        'plans.work_records.empty_cta': 'Record from Today\'s work',
        'plans.work_records.badge.from_schedule': 'From schedule',
        'plans.work_records.badge.adhoc': 'Ad hoc',
        'plans.work_records.badge.harvest': '収穫',
        'plans.work_records.yield': '収量 {{amount}} {{unit}}',
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
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: null,
      groups: []
    
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('uses unified plan context header with plan list L2 breadcrumb', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: []
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__back-nav')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('a.plan-context-header__back')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-plan-plan-context-header')).toBeTruthy();
  });

  it('renders grouped work records when data is loaded', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
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
    expect(text).toContain('Work log');
    expect(text).toContain('Weeding');
    expect(text).toContain('From schedule');
    expect(text).not.toContain('No work records yet');
  });

  it('formats month and date labels for the active locale', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
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

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('June 2026');
    expect(text).toContain('June 12, 2026');
    expect(text).not.toContain('2026-06');
    expect(text).not.toContain('2026-06-12');
  });

  it('renders unified empty state with link to today tab', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: []
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__empty-message')?.textContent?.trim()).toBe(
      'No work records yet'
    );
    const cta = fixture.nativeElement.querySelector('.plan-work__empty-cta-link');
    expect(cta?.textContent?.trim()).toBe("Record from Today's work");
    expect(cta?.getAttribute('href')).toContain('/plans/7/work');
  });

  it('renders translated API error instead of raw i18n key', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
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

  it('shows error with retry button and reloads when retry is clicked', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'common.api_error.generic': 'An error occurred',
        'plans.work.retry': 'Reload'
      },
      true
    );

    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: 'common.api_error.generic',
      plan: null,
      groups: []
    
    };
    fixture.detectChanges();

    const retryBtn = fixture.nativeElement.querySelector('.plan-work__retry');
    expect(retryBtn).toBeTruthy();
    expect(retryBtn.textContent).toContain('Reload');

    loadUseCase.execute.mockClear();
    retryBtn.click();
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('loads records on init when planId is valid', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('reloads records when route plan id changes', () => {
    fixture.detectChanges();
    loadUseCase.execute.mockClear();

    mockActivatedRoute.setPlanId('8');

    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 8 });
  });

  it('places photo thumbnails below record meta in a single column', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
              agricultural_task_id: null,
              name: 'Weeding',
              task_type: null,
              actual_date: '2026-06-12',
              amount: '10',
              amount_unit: 'kg',
              time_spent_minutes: null,
              notes: 'Done in the morning',
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const row = fixture.nativeElement.querySelector('.plan-work-records__row');
    const meta = row?.querySelector('.plan-work-records__meta');
    const photos = row?.querySelector('.plan-work-records__photos');

    expect(meta).toBeTruthy();
    expect(meta?.querySelector('.plan-work-records__date')).toBeTruthy();
    expect(meta?.querySelector('.plan-work-records__name')?.textContent).toContain('Weeding');
    expect(meta?.querySelector('.plan-work-records__amount')?.textContent).toContain('10 kg');
    expect(meta?.querySelector('.plan-work-records__notes')?.textContent).toContain('Done in the morning');
    expect(photos).toBeTruthy();
    expect(photos?.parentElement).toBe(row);
    expect(meta?.parentElement).toBe(row);
    expect(meta?.nextElementSibling).toBe(photos);
  });

  it('shows harvest badge and yield label for harvest records', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-07',
          averageDeltaDays: null,
          records: [
            {
              id: 9,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: 40,
              agricultural_task_id: 4,
              name: '収穫',
              task_type: 'general',
              actual_date: '2026-07-15',
              amount: '25',
              amount_unit: 'kg',
              time_spent_minutes: null,
              notes: null,
              created_at: '2026-07-15',
              updated_at: '2026-07-15',
              task_schedule_item: { id: 40, name: '収穫', scheduled_date: '2026-07-15' }
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const meta = fixture.nativeElement.querySelector('.plan-work-records__meta');
    expect(meta?.querySelector('.plan-work-records__badge--harvest')?.textContent?.trim()).toBe('収穫');
    expect(meta?.querySelector('.plan-work-records__amount--harvest')?.textContent).toContain('25');
    expect(meta?.querySelector('.plan-work-records__amount--harvest')?.textContent).toContain('kg');
  });

  it('renders field and crop name when present on the record', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
              agricultural_task_id: null,
              name: 'Weeding',
              task_type: null,
              actual_date: '2026-06-12',
              amount: null,
              amount_unit: null,
              time_spent_minutes: null,
              notes: null,
              field_name: 'North bed',
              crop_name: 'Tomato',
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: null
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const field = fixture.nativeElement.querySelector('.plan-work-records__field');
    expect(field?.textContent).toContain('North bed');
    expect(field?.textContent).toContain('Tomato');
  });

  it('renders up to three photo thumbnails for records with photos', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                },
                {
                  id: 2,
                  work_record_id: 1,
                  position: 1,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/2.jpg',
                  created_at: '2026-06-12'
                },
                {
                  id: 3,
                  work_record_id: 1,
                  position: 2,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/3.jpg',
                  created_at: '2026-06-12'
                },
                {
                  id: 4,
                  work_record_id: 1,
                  position: 3,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/4.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const thumbs = fixture.nativeElement.querySelectorAll('.plan-work-records__photo-thumb');
    expect(thumbs.length).toBe(3);
    expect(thumbs[0].querySelector('img')?.getAttribute('src')).toBe('/photos/1.jpg');
  });

  it('renders history photo thumbnails with landscape 4:3 aspect ratio and lazy loading', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const thumb = fixture.nativeElement.querySelector(
      '.plan-work-records__photo-thumb'
    ) as HTMLElement;
    expect(thumb).toBeTruthy();
    const img = thumb.querySelector('img') as HTMLImageElement;
    expect(img).toBeTruthy();
    expect(img.getAttribute('loading')).toBe('lazy');
    expect(img.getAttribute('decoding')).toBe('async');
    expect(img.getAttribute('width')).toBe(String(WORK_RECORD_PHOTO_THUMB_WIDTH_PX_HISTORY));
    expect(img.getAttribute('height')).toBe(String(WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_HISTORY));
    expect(getComputedStyle(thumb).aspectRatio).toBe(WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO);
    expect(getComputedStyle(thumb).width).toBe(WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY);
  });

  it('does not render photo thumbnails when record has no photos', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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

    expect(fixture.nativeElement.querySelector('.plan-work-records__photos')).toBeNull();
  });

  it('opens lightbox on thumbnail click without opening edit sheet', () => {
    const openEditSpy = vi.spyOn(component, 'openEdit');
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const thumbBtn = fixture.nativeElement.querySelector('.plan-work-records__photo-thumb');
    thumbBtn?.click();
    fixture.detectChanges();

    expect(openEditSpy).not.toHaveBeenCalled();
    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(component.lightboxPhotos).toHaveLength(1);
  });

  it('closes lightbox when close button is clicked', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    fixture.nativeElement.querySelector('.plan-work-records__photo-thumb')?.click();
    fixture.detectChanges();

    fixture.nativeElement.querySelector('.plan-work-records__lightbox-close')?.click();
    fixture.detectChanges();

    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
    expect(component.lightboxPhotos).toEqual([]);
  });

  it('navigates between photos in lightbox when multiple exist', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'plans.work_records.photos.close': 'Close',
        'plans.work_records.photos.prev': 'Previous photo',
        'plans.work_records.photos.next': 'Next photo',
        'plans.work_records.photos.view': 'View photo'
      },
      true
    );

    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
          records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
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
              task_schedule_item: null,
              photos: [
                {
                  id: 1,
                  work_record_id: 1,
                  position: 0,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/1.jpg',
                  created_at: '2026-06-12'
                },
                {
                  id: 2,
                  work_record_id: 1,
                  position: 1,
                  content_type: 'image/jpeg',
                  byte_size: 100,
                  url: '/photos/2.jpg',
                  created_at: '2026-06-12'
                }
              ]
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    fixture.nativeElement.querySelector('.plan-work-records__photo-thumb')?.click();
    fixture.detectChanges();

    const image = fixture.nativeElement.querySelector(
      '.plan-work-records__lightbox-image'
    ) as HTMLImageElement;
    expect(image?.src).toContain('/photos/1.jpg');

    fixture.nativeElement.querySelector('.plan-work-records__lightbox-next')?.click();
    fixture.detectChanges();
    expect(image?.src).toContain('/photos/2.jpg');

    fixture.nativeElement.querySelector('.plan-work-records__lightbox-prev')?.click();
    fixture.detectChanges();
    expect(image?.src).toContain('/photos/1.jpg');
  });

  it('renders variance columns for schedule-linked records and no-schedule label for ad hoc', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'plans.work_records.variance.scheduled': 'Scheduled {{date}}',
        'plans.work_records.variance.delta_days_late': '{{count}} days late',
        'plans.work_records.variance.delta_days_early': '{{count}} days early',
        'plans.work_records.variance.delta_days_on_time': 'On schedule',
        'plans.work_records.variance.gdd_at_actual': 'GDD {{value}}',
        'plans.work_records.variance.weather_snapshot':
          'High {{max}}°C / Low {{min}}°C (avg {{mean}}°C)',
        'plans.work_records.variance.no_schedule': 'No schedule',
        'plans.work_records.variance.month_average_late': 'Avg. {{count}} days late'
      },
      true
    );

    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: 2,
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
              gdd_at_actual: 120.5,
              weather_snapshot: {
                date: '2026-06-12',
                temperature_max: 28,
                temperature_min: 18,
                temperature_mean: 23
              },
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' }
            },
            {
              id: 2,
              cultivation_plan_id: 7,
              field_cultivation_id: 10,
              task_schedule_item_id: null,
              agricultural_task_id: null,
              name: 'Ad hoc task',
              task_type: null,
              actual_date: '2026-06-11',
              amount: null,
              amount_unit: null,
              time_spent_minutes: null,
              notes: null,
              weather_snapshot: {
                date: '2026-06-11',
                temperature_max: 25,
                temperature_min: 15,
                temperature_mean: 20
              },
              created_at: '2026-06-11',
              updated_at: '2026-06-11',
              task_schedule_item: null
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Scheduled June 10, 2026');
    expect(text).toContain('2 days late');
    expect(text).toContain('GDD 120.5');
    expect(text).toContain('High 28°C / Low 18°C (avg 23°C)');
    expect(text).toContain('No schedule');
    expect(text).toContain('High 25°C / Low 15°C (avg 20°C)');
    expect(text).toContain('Avg. 2 days late');

    const varianceRows = fixture.nativeElement.querySelectorAll('.plan-work-records__variance');
    expect(varianceRows.length).toBe(2);
    expect(
      varianceRows[0]?.querySelector('.plan-work-records__variance-weather')?.textContent
    ).toContain('28');
  });

  it('omits weather snapshot row when snapshot is absent', () => {
    fixture.detectChanges();
    component.control = {
      ...SAVE_IMPACT_DEFAULTS,
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          averageDeltaDays: null,
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
              gdd_at_actual: 120.5,
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' }
            }
          ]
        }
      ]
    };
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('.plan-work-records__variance-weather')
    ).toBeNull();
  });
});
