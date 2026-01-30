import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskCreateView } from '../../components/masters/agricultural-tasks/agricultural-task-create.view';
import { CreateAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/create-agricultural-task.output-port';
import { CreateAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/create-agricultural-task.dtos';

@Injectable()
export class AgriculturalTaskCreatePresenter implements CreateAgriculturalTaskOutputPort {
  private view: AgriculturalTaskCreateView | null = null;

  setView(view: AgriculturalTaskCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateAgriculturalTaskSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}