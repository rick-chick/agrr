import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkRecordSheetComponent } from './work-record-sheet.component';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { LoadAgriculturalTaskListUseCase } from '../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { CreateWorkRecordUseCase } from '../../usecase/plans/create-work-record.usecase';
import { UpdateWorkRecordUseCase } from '../../usecase/plans/update-work-record.usecase';
import { DeleteWorkRecordUseCase } from '../../usecase/plans/delete-work-record.usecase';

describe('WorkRecordSheetComponent', () => {
  let fixture: ComponentFixture<WorkRecordSheetComponent>;
  let component: WorkRecordSheetComponent;
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let loadTaskListUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockPresenter = { setView: vi.fn() };
    loadTaskListUseCase = { execute: vi.fn() };
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

    TestBed.overrideComponent(WorkRecordSheetComponent, {
      set: {
        providers: [
          { provide: WorkRecordSheetPresenter, useValue: mockPresenter },
          { provide: CreateWorkRecordUseCase, useValue: { execute: vi.fn() } },
          { provide: UpdateWorkRecordUseCase, useValue: { execute: vi.fn() } },
          { provide: DeleteWorkRecordUseCase, useValue: { execute: vi.fn() } },
          { provide: LoadAgriculturalTaskListUseCase, useValue: loadTaskListUseCase },
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
      'plans.work.sheet.submit': '記録する',
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
});
