import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { CropDetailComponent } from './crop-detail.component';
import type { CropDetailViewState } from './crop-detail.view';
import { CropDetailPresenter } from '../../../usecase/crops/crop-detail.providers';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import {
  defaultBlueprintReadiness,
  withCropDetailSummaryState
} from '../../../adapters/crops/crop-detail-presenter.helpers';

const loadedState: CropDetailViewState = withCropDetailSummaryState({
  loading: false,
  error: null,
  crop: {
    id: 3,
    name: 'Tomato',
    variety: null,
    area_per_unit: null,
    revenue_per_area: null,
    groups: [],
    region: 'jp',
    is_reference: false,
    crop_stages: [],
    created_at: null,
    updated_at: null
  },
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  blueprintsLoading: false,
  blueprintCount: 1,
  blueprintReadiness: { ...defaultBlueprintReadiness(), blueprintsReady: true, ready: false }
});

describe('CropDetailComponent', () => {
  let fixture: ComponentFixture<CropDetailComponent>;
  let component: CropDetailComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
    };
  };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockActivatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '3') }
      }
    };

    TestBed.overrideComponent(CropDetailComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadCropDetailUseCase, useValue: loadUseCase },
          { provide: DeleteCropUseCase, useValue: { execute: vi.fn() } },
          { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase },
          { provide: CropDetailPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } },
          { provide: ActivatedRoute, useValue: mockActivatedRoute }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [CropDetailComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(CropDetailComponent);
    component = fixture.componentInstance;
  });

  it('loads crop detail and blueprint summary on init', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('shows error message when control has error and no crop', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      { crops: { errors: { invalid_id: 'Invalid crop ID' } } },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      loading: false,
      error: 'Invalid crop ID',
      crop: null,
      blueprintsLoading: false
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.master-error')?.textContent).toContain('Invalid crop ID');
  });

  it('links to task schedule blueprints page from summary', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector(
      'a[href*="/crops/3/task_schedule_blueprints"]'
    ) as HTMLAnchorElement | null;
    expect(link).toBeTruthy();
    expect(link?.textContent).toContain('Edit task plans');
    expect(fixture.nativeElement.querySelector('#blueprints-heading')).toBeFalsy();
  });

  it('formats created_at using the active app language', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', { crops: { show: { created_at: '作成日' } } }, true);
    translate.setDefaultLang('ja');
    translate.use('ja');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      crop: {
        ...loadedState.crop!,
        created_at: '2026-06-25 09:03:01'
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('2026年6月25日 9:03');
  });
});
