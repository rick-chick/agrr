import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BehaviorSubject } from 'rxjs';
import { PlanWorkRecordsComponent } from './plan-work-records.component';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import {
  WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO,
  WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY
} from '../../domain/plans/work-record-photo.constants';

describe('PlanWorkRecordsComponent photo thumb layout', () => {
  let fixture: ComponentFixture<PlanWorkRecordsComponent>;
  let component: PlanWorkRecordsComponent;

  beforeEach(async () => {
    const loadUseCase = { execute: vi.fn() };
    const mockPresenter = { setView: vi.fn() };
    const cdr = { markForCheck: vi.fn() };
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    const paramMapSubject = new BehaviorSubject({
      get: (key: string) => (key === 'id' ? '7' : null)
    });
    const queryParamMapSubject = new BehaviorSubject({
      get: () => null
    });

    TestBed.overrideComponent(PlanWorkRecordsComponent, {
      set: {
        providers: [
          { provide: LoadWorkRecordsUseCase, useValue: loadUseCase },
          { provide: PlanWorkRecordsPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                get paramMap() {
                  return paramMapSubject.value;
                },
                queryParamMap: { get: () => null }
              },
              paramMap: paramMapSubject.asObservable(),
              queryParamMap: queryParamMapSubject.asObservable()
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkRecordsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.work_records.badge.from_schedule': 'From schedule',
        'plans.work_records.badge.adhoc': 'Ad hoc',
        'plans.work_records.photos.view': 'View photo'
      },
      true
    );

    fixture = TestBed.createComponent(PlanWorkRecordsComponent);
    component = fixture.componentInstance;
  });

  it('renders history photo thumbnails with landscape 4:3 aspect ratio', () => {
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

    const thumb = fixture.nativeElement.querySelector(
      '.plan-work-records__photo-thumb'
    ) as HTMLElement;
    expect(thumb).toBeTruthy();
    expect(getComputedStyle(thumb).aspectRatio).toBe(WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO);
    expect(getComputedStyle(thumb).width).toBe(WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY);
  });
});
