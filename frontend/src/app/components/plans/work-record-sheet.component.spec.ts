import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkRecordSheetComponent } from './work-record-sheet.component';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { LoadAgriculturalTaskListUseCase } from '../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadFertilizeListUseCase } from '../../usecase/fertilizes/load-fertilize-list.usecase';
import { LoadCropPesticideListUseCase } from '../../usecase/pesticides/load-crop-pesticide-list.usecase';
import { SaveWorkRecordSheetUseCase } from '../../usecase/plans/save-work-record-sheet.usecase';
import { DeleteWorkRecordUseCase } from '../../usecase/plans/delete-work-record.usecase';
import { PreviewWorkRecordClimateUseCase } from '../../usecase/plans/preview-work-record-climate/preview-work-record-climate.usecase';
import {
  WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO,
  WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET,
  WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET,
  WORK_RECORD_PHOTO_THUMB_WIDTH_SHEET
} from '../../domain/plans/work-record-photo.constants';

describe('WorkRecordSheetComponent', () => {
  let fixture: ComponentFixture<WorkRecordSheetComponent>;
  let component: WorkRecordSheetComponent;
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let loadTaskListUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadFertilizeListUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadCropPesticideListUseCase: { execute: ReturnType<typeof vi.fn> };
  let previewClimateUseCase: { execute: ReturnType<typeof vi.fn> };
  let saveUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockPresenter = { setView: vi.fn() };
    loadTaskListUseCase = { execute: vi.fn() };
    loadFertilizeListUseCase = { execute: vi.fn() };
    loadCropPesticideListUseCase = { execute: vi.fn() };
    previewClimateUseCase = { execute: vi.fn() };
    saveUseCase = { execute: vi.fn() };
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    TestBed.overrideComponent(WorkRecordSheetComponent, {
      set: {
        providers: [
          { provide: WorkRecordSheetPresenter, useValue: mockPresenter },
          { provide: SaveWorkRecordSheetUseCase, useValue: saveUseCase },
          { provide: DeleteWorkRecordUseCase, useValue: { execute: vi.fn() } },
          { provide: LoadAgriculturalTaskListUseCase, useValue: loadTaskListUseCase },
          { provide: LoadFertilizeListUseCase, useValue: loadFertilizeListUseCase },
          { provide: LoadCropPesticideListUseCase, useValue: loadCropPesticideListUseCase },
          { provide: PreviewWorkRecordClimateUseCase, useValue: previewClimateUseCase },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [WorkRecordSheetComponent, FormsModule, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.work.sheet.title': '作業を記録',
      'plans.work.sheet.name': '作業名',
      'plans.work.sheet.task_picker': '作業を選ぶ',
      'plans.work.sheet.task_other': 'その他',
      'plans.work.sheet.actual_date': '実施日',
      'plans.work.sheet.amount': '量',
      'plans.work.sheet.amount_unit': '単位',
      'plans.work.sheet.time_spent': '所要時間（分・任意）',
      'plans.work.sheet.notes': 'メモ（任意）',
      'plans.work.sheet.field': '圃場',
      'plans.work.sheet.field_select': '圃場（任意）',
      'plans.work.sheet.field_optional': '未選択',
      'plans.work.sheet.show_details': '詳細を追加',
      'plans.work.sheet.hide_details': '詳細を閉じる',
      'plans.work.sheet.fertilizer.planned_amount': '予定用量',
      'plans.work.sheet.fertilizer.planned_amount_empty': '予定用量なし',
      'plans.work.sheet.fertilizer.actual_amount': '実施用量',
      'plans.work.sheet.fertilizer.master_label': '使用肥料',
      'plans.work.sheet.fertilizer.master_placeholder': '肥料を選択（任意）',
      'plans.work.sheet.fertilizer.master_empty': '登録済みの肥料がありません',
      'plans.work.sheet.fertilizer.master_add_link': '肥料マスタを登録する',
      'plans.work.sheet.pest_control.planned_amount': '予定散布量',
      'plans.work.sheet.pest_control.planned_amount_empty': '予定散布量なし',
      'plans.work.sheet.pest_control.actual_amount': '実施散布量',
      'plans.work.sheet.pest_control.master_label': '使用農薬',
      'plans.work.sheet.pest_control.master_placeholder': '農薬を選択（任意）',
      'plans.work.sheet.pest_control.master_empty': 'この作物向けの登録農薬がありません',
      'plans.work.sheet.pest_control.master_add_link': '農薬マスタを登録する',
      'plans.work.sheet.pest_control.master_crop_required': '圃場を選択すると、この作物向けの農薬を選べます',
      'plans.work.sheet.harvest.yield_amount': '収量',
      'plans.work.sheet.harvest.yield_unit': '収量の単位',
      'plans.work.sheet.climate_preview.label': '記録時に保存される気象情報',
      'plans.work.sheet.climate_preview.loading': '気象データを読み込み中…',
      'plans.work.sheet.climate_preview.unavailable': 'この日付の気象データがありません',
      'plans.work.sheet.climate_preview.gdd': 'GDD {{value}}',
      'plans.work.sheet.climate_preview.planned_gdd': '予定 GDD {{value}}',
      'plans.work.sheet.climate_preview.gdd_delta': '予定比 {{value}}',
      'plans.work.sheet.climate_preview.weather':
        '最高{{max}}°C / 最低{{min}}°C（平均{{mean}}°C）',
      'plans.work.sheet.submit': '記録する',
      'plans.work.sheet.photos.label': '写真',
      'plans.work.sheet.photos.remove': '削除',
      'common.cancel': 'キャンセル',
      'common.loading': '読み込み中…'
    });

    fixture = TestBed.createComponent(WorkRecordSheetComponent);
    component = fixture.componentInstance;
    component.planId = 1;
    fixture.detectChanges();
  });

  it('renders a modal form dialog with shared form layout classes', () => {
    component.openAdHoc([]);
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('dialog.form-dialog');
    expect(dialog).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.form-card__form')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.form-card__actions .btn-primary')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('作業を記録');
    expect(loadTaskListUseCase.execute).toHaveBeenCalled();
  });

  it('shows task chips for ad-hoc mode and hides detail fields until expanded', () => {
    component.openAdHoc([]);
    component.control = {
      ...component.control,
      loadingTaskChips: false,
      taskChips: [
        { id: 1, name: '除草', task_type: null },
        { id: 2, name: '追肥', task_type: null }
      ]
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.work-record-sheet__chips')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('除草');
    expect(fixture.nativeElement.querySelector('#wr-amount')).toBeNull();

    const toggle = fixture.nativeElement.querySelector('.work-record-sheet__details-toggle') as HTMLButtonElement;
    toggle.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('#wr-amount')).toBeTruthy();
  });

  it('enables submit after selecting a task chip without typing', () => {
    component.openAdHoc([]);
    component.control = {
      ...component.control,
      loadingTaskChips: false,
      taskChips: [{ id: 1, name: '除草', task_type: null }]
    };
    fixture.detectChanges();

    const chip = fixture.nativeElement.querySelector('.work-record-sheet__chip') as HTMLButtonElement;
    chip.click();
    fixture.detectChanges();

    const submit = fixture.nativeElement.querySelector(
      '.form-card__actions .btn-primary'
    ) as HTMLButtonElement;
    expect(submit.disabled).toBe(false);
    expect(component.control.form.name).toBe('除草');
  });

  it('renders photo thumbnails with landscape 4:3 aspect ratio', () => {
    component.openAdHoc([]);
    component.control = {
      ...component.control,
      existingPhotos: [{ id: 1, url: '/photos/1.jpg', markedForDelete: false }]
    };
    fixture.detectChanges();

    const thumb = fixture.nativeElement.querySelector(
      '.work-record-sheet__photo-thumb'
    ) as HTMLElement;
    expect(thumb).toBeTruthy();
    const img = thumb.querySelector('img') as HTMLImageElement;
    expect(img.getAttribute('loading')).toBe('lazy');
    expect(img.getAttribute('decoding')).toBe('async');
    expect(img.getAttribute('width')).toBe(String(WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET));
    expect(img.getAttribute('height')).toBe(String(WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET));
    expect(getComputedStyle(thumb).aspectRatio).toBe(WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO);
    expect(getComputedStyle(thumb).width).toBe(WORK_RECORD_PHOTO_THUMB_WIDTH_SHEET);
  });

  it('renders pending photo thumbnails with lazy loading and intrinsic dimensions', () => {
    component.openAdHoc([]);
    component.control = {
      ...component.control,
      pendingPhotos: [
        {
          clientId: 'pending-1',
          previewUrl: 'blob:http://localhost/pending-1',
          file: new File(['x'], 'photo.jpg', { type: 'image/jpeg' })
        }
      ]
    };
    fixture.detectChanges();

    const img = fixture.nativeElement.querySelector(
      '.work-record-sheet__photo-thumb img'
    ) as HTMLImageElement;
    expect(img).toBeTruthy();
    expect(img.getAttribute('loading')).toBe('lazy');
    expect(img.getAttribute('decoding')).toBe('async');
    expect(img.getAttribute('width')).toBe(String(WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET));
    expect(img.getAttribute('height')).toBe(String(WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET));
  });

  it('shows pest control planned spray amount, prefilled actual amount, and diff for scheduled pest control items', () => {
    component.openFromItem({
      item: {
        item_id: 20,
        name: '予防散布',
        task_type: 'preventive_spray',
        category: 'pest_control',
        scheduled_date: '2026-07-01',
        priority: 1,
        source: 'plan',
        weather_dependency: 'low',
        time_per_sqm: '0',
        amount: '5',
        amount_unit: 'L',
        status: 'scheduled',
        agricultural_task_id: 3,
        field_cultivation_id: 8,
        completed: false,
        work_records: [],
        details: {} as never,
        badge: { type: 'pest_control' }
      },
      fieldName: 'C圃場',
      cropName: 'ナス',
      recordedToday: false
    });
    component.control = {
      ...component.control,
      form: {
        ...component.control.form,
        amount: '3'
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('予定散布量');
    expect(fixture.nativeElement.textContent).toContain('5 L');
    expect(fixture.nativeElement.textContent).toContain('実施散布量');
    expect(fixture.nativeElement.querySelector('#wr-amount')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('-2 L');
  });

  it('shows fertilizer planned amount, prefilled actual amount, and diff for scheduled fertilizer items', () => {
    component.openFromItem({
      item: {
        item_id: 10,
        name: '追肥',
        task_type: 'fertilizer',
        category: 'fertilizer',
        scheduled_date: '2026-06-12',
        priority: 1,
        source: 'plan',
        weather_dependency: 'low',
        time_per_sqm: '0',
        amount: '10',
        amount_unit: 'kg',
        status: 'scheduled',
        agricultural_task_id: 1,
        field_cultivation_id: 5,
        completed: false,
        work_records: [],
        details: {} as never,
        badge: { type: 'fertilizer' }
      },
      fieldName: 'A圃場',
      cropName: 'トマト',
      recordedToday: false
    });
    component.control = {
      ...component.control,
      form: {
        ...component.control.form,
        amount: '12'
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('予定用量');
    expect(fixture.nativeElement.textContent).toContain('10 kg');
    expect(fixture.nativeElement.textContent).toContain('実施用量');
    expect(fixture.nativeElement.querySelector('#wr-amount')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('+2 kg');
    expect(previewClimateUseCase.execute).toHaveBeenCalledWith({
      fieldCultivationId: 5,
      actualDate: component.control.form.actual_date,
      gddTrigger: null
    });
  });

  it('shows climate preview row when field cultivation and date are set', () => {
    component.openFromItem({
      item: {
        item_id: 11,
        name: '除草',
        task_type: 'general',
        category: 'general',
        scheduled_date: '2026-06-12',
        priority: 1,
        source: 'plan',
        weather_dependency: 'low',
        time_per_sqm: '0',
        amount: '',
        amount_unit: '',
        status: 'scheduled',
        agricultural_task_id: 2,
        field_cultivation_id: 7,
        completed: false,
        work_records: [],
        details: {} as never,
        badge: { type: 'general' }
      },
      fieldName: 'B圃場',
      cropName: 'キュウリ',
      recordedToday: false
    });
    component.control = {
      ...component.control,
      showDetails: true,
      climatePreview: {
        gddAtActual: 145.25,
        weatherDate: '2026-06-12',
        temperatureMax: 30,
        temperatureMin: 20,
        temperatureMean: 25,
        plannedGdd: null,
        gddDelta: null,
        loading: false
      }
    };
    fixture.detectChanges();

    const preview = fixture.nativeElement.querySelector('[data-testid="climate-preview"]');
    expect(preview).toBeTruthy();
    expect(preview.textContent).toContain('記録時に保存される気象情報');
    expect(preview.textContent).toContain('GDD 145.25');
    expect(preview.textContent).toContain('最高30°C');
  });

  it('shows planned GDD comparison in climate preview when trigger is available', () => {
    component.openFromItem({
      item: {
        item_id: 11,
        name: '除草',
        task_type: 'general',
        category: 'general',
        scheduled_date: '2026-06-12',
        priority: 1,
        source: 'plan',
        weather_dependency: 'low',
        time_per_sqm: '0',
        amount: '',
        amount_unit: '',
        status: 'scheduled',
        agricultural_task_id: 2,
        field_cultivation_id: 7,
        gdd_trigger: '100',
        completed: false,
        work_records: [],
        details: {} as never,
        badge: { type: 'general' }
      },
      fieldName: 'B圃場',
      cropName: 'キュウリ',
      recordedToday: false
    });
    component.control = {
      ...component.control,
      showDetails: true,
      climatePreview: {
        gddAtActual: 145.25,
        weatherDate: '2026-06-12',
        temperatureMax: 30,
        temperatureMin: 20,
        temperatureMean: 25,
        plannedGdd: 100,
        gddDelta: 45.3,
        loading: false
      }
    };
    fixture.detectChanges();

    const preview = fixture.nativeElement.querySelector('[data-testid="climate-preview"]');
    expect(preview.textContent).toContain('予定 GDD 100');
    expect(preview.textContent).toContain('予定比 +45.3');
    expect(previewClimateUseCase.execute).toHaveBeenCalledWith({
      fieldCultivationId: 7,
      actualDate: component.control.form.actual_date,
      gddTrigger: '100'
    });
  });

  it('does not show planned GDD comparison in edit mode without gdd trigger', () => {
    component.openEdit({
      id: 99,
      cultivation_plan_id: 1,
      field_cultivation_id: 7,
      task_schedule_item_id: 11,
      agricultural_task_id: 2,
      name: '除草',
      task_type: 'general',
      actual_date: '2026-06-12',
      amount: null,
      amount_unit: null,
      time_spent_minutes: null,
      notes: null,
      created_at: '2026-06-12',
      updated_at: '2026-06-12',
      task_schedule_item: { id: 11, name: '除草', scheduled_date: '2026-06-10' }
    });
    component.control = {
      ...component.control,
      showDetails: true,
      climatePreview: {
        gddAtActual: 145.25,
        weatherDate: '2026-06-12',
        temperatureMax: 30,
        temperatureMin: 20,
        temperatureMean: 25,
        plannedGdd: null,
        gddDelta: null,
        loading: false
      }
    };
    fixture.detectChanges();

    const preview = fixture.nativeElement.querySelector('[data-testid="climate-preview"]');
    expect(preview.textContent).toContain('GDD 145.25');
    expect(preview.textContent).not.toContain('予定 GDD');
    expect(preview.textContent).not.toContain('予定比');
    expect(previewClimateUseCase.execute).toHaveBeenCalledWith({
      fieldCultivationId: 7,
      actualDate: '2026-06-12',
      gddTrigger: null
    });
  });

  it('shows emphasized harvest yield fields for scheduled harvest items', () => {
    component.openFromItem({
      item: {
        item_id: 20,
        name: '収穫',
        task_type: 'general',
        category: 'general',
        scheduled_date: '2026-07-15',
        priority: 1,
        source: 'plan',
        weather_dependency: 'low',
        time_per_sqm: '0',
        amount: '50',
        amount_unit: 'kg',
        status: 'scheduled',
        agricultural_task_id: 4,
        field_cultivation_id: 9,
        completed: false,
        work_records: [],
        details: {
          stage: { name: '収穫期', order: 3 },
          gdd: { trigger: '', tolerance: '' },
          priority: 1,
          weather_dependency: 'low',
          time_per_sqm: '0',
          amount: '',
          amount_unit: '',
          source: 'plan',
          master: null,
          history: { rescheduled_at: null, cancelled_at: null }
        },
        badge: { type: 'general' }
      },
      fieldName: 'D圃場',
      cropName: 'キャベツ',
      recordedToday: false
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('収量');
    expect(fixture.nativeElement.textContent).toContain('収量の単位');
    expect(fixture.nativeElement.querySelector('.form-card__field--harvest-yield')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#wr-amount')).toBeTruthy();
    expect(component.control.form.amount).toBe('50');
    expect(component.control.form.amount_unit).toBe('kg');
  });

  it('shows fertilizer master picker and sends fertilize_id on save for fertilizer items', () => {
    component.openFromItem(
      {
        item: {
          item_id: 10,
          name: '追肥',
          task_type: 'fertilizer',
          category: 'fertilizer',
          scheduled_date: '2026-06-12',
          priority: 1,
          source: 'plan',
          weather_dependency: 'low',
          time_per_sqm: '0',
          amount: '10',
          amount_unit: 'kg',
          status: 'scheduled',
          agricultural_task_id: 1,
          field_cultivation_id: 5,
          completed: false,
          work_records: [],
          details: {} as never,
          badge: { type: 'fertilizer' }
        },
        fieldName: 'A圃場',
        cropName: 'トマト',
        recordedToday: false
      },
      { cropId: 42 }
    );
    component.control = {
      ...component.control,
      fertilizeOptions: [
        { id: 7, name: '尿素' },
        { id: 8, name: '堆肥' }
      ],
      form: {
        ...component.control.form,
        fertilize_id: 7
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="fertilize-master-picker"]')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('使用肥料');
    expect(loadFertilizeListUseCase.execute).toHaveBeenCalled();

    component.submit();
    expect(saveUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        createBody: expect.objectContaining({ fertilize_id: 7, task_schedule_item_id: 10 })
      })
    );
  });

  it('shows crop-scoped pesticide picker for pest control items when cropId is known', () => {
    component.openFromItem(
      {
        item: {
          item_id: 20,
          name: '予防散布',
          task_type: 'preventive_spray',
          category: 'pest_control',
          scheduled_date: '2026-07-01',
          priority: 1,
          source: 'plan',
          weather_dependency: 'low',
          time_per_sqm: '0',
          amount: '5',
          amount_unit: 'L',
          status: 'scheduled',
          agricultural_task_id: 3,
          field_cultivation_id: 8,
          completed: false,
          work_records: [],
          details: {} as never,
          badge: { type: 'pest_control' }
        },
        fieldName: 'C圃場',
        cropName: 'ナス',
        recordedToday: false
      },
      { cropId: 99 }
    );
    component.control = {
      ...component.control,
      pesticideOptions: [{ id: 3, name: '殺虫剤A' }],
      form: {
        ...component.control.form,
        pesticide_id: 3
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="pesticide-master-picker"]')).toBeTruthy();
    expect(loadCropPesticideListUseCase.execute).toHaveBeenCalledWith({ cropId: 99 });

    component.submit();
    expect(saveUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        createBody: expect.objectContaining({ pesticide_id: 3, task_schedule_item_id: 20 })
      })
    );
  });
});
