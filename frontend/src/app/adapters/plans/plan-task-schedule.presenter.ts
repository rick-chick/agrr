import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanTaskScheduleView } from '../../components/plans/plan-task-schedule.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';

@Injectable()
export class PlanTaskSchedulePresenter implements LoadPlanTaskScheduleOutputPort {
  private view: PlanTaskScheduleView | null = null;

  setView(view: PlanTaskScheduleView): void {
    this.view = view;
  }

  present(dto: PlanTaskScheduleDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      schedule: dto.schedule
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      schedule: null
    };
  }
}
