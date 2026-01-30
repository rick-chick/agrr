import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskEditView } from '../../components/masters/agricultural-tasks/agricultural-task-edit.view';
import { LoadAgriculturalTaskForEditOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-for-edit.output-port';
import { LoadAgriculturalTaskForEditDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-for-edit.dtos';
import { UpdateAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/update-agricultural-task.output-port';
import { UpdateAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/update-agricultural-task.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class AgriculturalTaskEditPresenter implements LoadAgriculturalTaskForEditOutputPort, UpdateAgriculturalTaskOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: AgriculturalTaskEditView | null = null;

  setView(view: AgriculturalTaskEditView): void {
    this.view = view;
  }

  present(dto: LoadAgriculturalTaskForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const agriculturalTask = dto.agriculturalTask;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      formData: {
        name: agriculturalTask.name,
        description: agriculturalTask.description ?? null,
        time_per_sqm: agriculturalTask.time_per_sqm ?? null,
        weather_dependency: agriculturalTask.weather_dependency ?? undefined,
        required_tools: agriculturalTask.required_tools ?? [],
        skill_level: agriculturalTask.skill_level ?? undefined,
        region: agriculturalTask.region ?? null,
        task_type: agriculturalTask.task_type ?? null
      }
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: null
    };
  }

  onSuccess(_dto: UpdateAgriculturalTaskSuccessDto): void {}
}