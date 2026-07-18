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
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  let mockActivatedRoute: ReturnType<typeof createPlanRouteMock>;

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };
    mockActivatedRoute = createPlanRouteMock('7');
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    TestBed.overrideComponent(PlanWorkRecordsComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkRecordsUseCase, useValue: loadUseCase },
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

  it('uses unified plan context header without redundant breadcrumb links', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: { id: 7, name: 'Field plan' },
      groups: []
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__back-nav')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-plan-context-header')).toBeTruthy();
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
    expect(text).toContain('Work log');
    expect(text).toContain('Weeding');
    expect(text).toContain('From schedule');
    expect(text).not.toContain('No work records yet');
  });

  it('formats month and date labels for the active locale', () => {
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

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('June 2026');
    expect(text).toContain('June 12, 2026');
    expect(text).not.toContain('2026-06');
    expect(text).not.toContain('2026-06-12');
  });

  it('renders unified empty state with link to today tab', () => {
    fixture.detectChanges();
    component.control = {
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

  it('renders field and crop name when present on the record', () => {
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

  it('does not render photo thumbnails when record has no photos', () => {
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
});
