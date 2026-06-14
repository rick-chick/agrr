import { Injectable } from '@angular/core';
import { PlanWorkRecordsView } from '../../components/plans/plan-work-records.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadWorkRecordsDataDto } from '../../usecase/plans/load-work-records.dtos';
import { LoadWorkRecordsOutputPort } from '../../usecase/plans/load-work-records.output-port';

@Injectable()
export class PlanWorkRecordsPresenter implements LoadWorkRecordsOutputPort {
  private view: PlanWorkRecordsView | null = null;

  setView(view: PlanWorkRecordsView): void {
    this.view = view;
  }

  present(dto: LoadWorkRecordsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      plan: dto.plan,
      groups: dto.groups
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      plan: null,
      groups: []
    };
  }
}
