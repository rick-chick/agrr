import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { PlanWorkView } from '../../components/plans/plan-work.view';
import { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { UndoToastService } from '../../services/undo-toast.service';
import {
  CreateWorkRecordSuccessDto,
  CreateWorkRecordValidationErrorDto
} from '../../usecase/plans/create-work-record.dtos';
import { CreateWorkRecordOutputPort } from '../../usecase/plans/create-work-record.output-port';
import { LoadWorkDayListDataDto } from '../../usecase/plans/load-work-day-list.dtos';
import { LoadWorkDayListOutputPort } from '../../usecase/plans/load-work-day-list.output-port';
import { SkipTaskScheduleItemOutputPort } from '../../usecase/plans/skip-task-schedule-item.output-port';

@Injectable()
export class PlanWorkPresenter
  implements LoadWorkDayListOutputPort, SkipTaskScheduleItemOutputPort, CreateWorkRecordOutputPort
{
  private readonly toast = inject(UndoToastService);
  private readonly translate = inject(TranslateService);

  private view: PlanWorkView | null = null;
  onSkipSuccessCallback: (() => void) | null = null;
  onRecordSavedCallback: ((event: WorkRecordSheetSavedEvent) => void) | null = null;
  onQuickCompleteValidationErrorCallback:
    | ((itemId: number, fieldErrors: Record<string, string[]>) => void)
    | null = null;

  setView(view: PlanWorkView): void {
    this.view = view;
  }

  onSuccess(dto?: CreateWorkRecordSuccessDto): void {
    if (dto?.workRecord != null) {
      this.handleQuickCompleteSuccess(dto);
      return;
    }
    this.onSkipSuccessCallback?.();
  }

  present(dto: LoadWorkDayListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      plan: dto.plan,
      fields: dto.fields,
      overdue: dto.overdue,
      today: dto.today,
      upcoming: dto.upcoming
    };
  }

  onValidationError(dto: CreateWorkRecordValidationErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const itemId = this.view.control.completingItemId;
    if (itemId == null) return;
    this.view.control = { ...this.view.control, completingItemId: null };
    this.onQuickCompleteValidationErrorCallback?.(itemId, dto.fieldErrors);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.completingItemId != null) {
      this.view.control = {
        ...this.view.control,
        completingItemId: null,
        error: dto.message
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      plan: null,
      fields: [],
      overdue: [],
      today: [],
      upcoming: []
    };
  }

  private handleQuickCompleteSuccess(dto: CreateWorkRecordSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      completingItemId: null,
      error: null
    };
    this.toast.show(this.translate.instant('plans.work.toast.record_saved'));
    this.onRecordSavedCallback?.({
      workRecord: dto.workRecord,
      mode: 'create-from-item'
    });
  }
}
