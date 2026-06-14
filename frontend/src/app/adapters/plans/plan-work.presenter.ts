import { Injectable } from '@angular/core';
import { PlanWorkView } from '../../components/plans/plan-work.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadWorkDayListDataDto } from '../../usecase/plans/load-work-day-list.dtos';
import { LoadWorkDayListOutputPort } from '../../usecase/plans/load-work-day-list.output-port';
import { SkipTaskScheduleItemOutputPort } from '../../usecase/plans/skip-task-schedule-item.output-port';

@Injectable()
export class PlanWorkPresenter implements LoadWorkDayListOutputPort, SkipTaskScheduleItemOutputPort {
  private view: PlanWorkView | null = null;
  onSkipSuccessCallback: (() => void) | null = null;

  setView(view: PlanWorkView): void {
    this.view = view;
  }

  onSuccess(): void {
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

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
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
}
