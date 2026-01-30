import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskListView } from '../../components/masters/agricultural-tasks/agricultural-task-list.view';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';

@Injectable()
export class AgriculturalTaskListPresenter implements LoadAgriculturalTaskListOutputPort {
  private view: AgriculturalTaskListView | null = null;

  setView(view: AgriculturalTaskListView): void {
    this.view = view;
  }

  present(dto: AgriculturalTaskListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      tasks: dto.tasks
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      tasks: []
    };
  }
}
