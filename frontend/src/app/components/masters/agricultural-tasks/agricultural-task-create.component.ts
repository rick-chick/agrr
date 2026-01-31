import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  AgriculturalTaskCreateView,
  AgriculturalTaskCreateViewState,
  AgriculturalTaskCreateFormData
} from './agricultural-task-create.view';
import { CreateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/create-agricultural-task.usecase';
import { AgriculturalTaskCreatePresenter } from '../../../adapters/agricultural-tasks/agricultural-task-create.presenter';
import { CREATE_AGRICULTURAL_TASK_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/create-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY } from '../../../usecase/agricultural-tasks/agricultural-task-gateway';
import { AgriculturalTaskApiGateway } from '../../../adapters/agricultural-tasks/agricultural-task-api.gateway';

const initialFormData: AgriculturalTaskCreateFormData = {
  name: '',
  description: null,
  time_per_sqm: null,
  weather_dependency: null,
  required_tools: [],
  skill_level: null,
  region: null,
  task_type: null
};

const initialControl: AgriculturalTaskCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-agricultural-task-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    AgriculturalTaskCreatePresenter,
    CreateAgriculturalTaskUseCase,
    { provide: CREATE_AGRICULTURAL_TASK_OUTPUT_PORT, useExisting: AgriculturalTaskCreatePresenter },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">New Agricultural Task</h2>
        <form (ngSubmit)="createAgriculturalTask()" #taskForm="ngForm" class="form-card__form">
          <label for="name" class="form-card__field">
            <span class="form-card__field-label">Name</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label for="description" class="form-card__field">
            <span class="form-card__field-label">Description</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <label for="time_per_sqm" class="form-card__field">
            <span class="form-card__field-label">Time per sqm (hours)</span>
            <input id="time_per_sqm" name="time_per_sqm" type="number" step="0.01" [(ngModel)]="control.formData.time_per_sqm" />
          </label>
          <label for="weather_dependency" class="form-card__field">
            <span class="form-card__field-label">Weather dependency</span>
            <select id="weather_dependency" name="weather_dependency" [(ngModel)]="control.formData.weather_dependency">
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </select>
          </label>
          <label for="skill_level" class="form-card__field">
            <span class="form-card__field-label">Skill level</span>
            <select id="skill_level" name="skill_level" [(ngModel)]="control.formData.skill_level">
              <option value="beginner">Beginner</option>
              <option value="intermediate">Intermediate</option>
              <option value="advanced">Advanced</option>
            </select>
          </label>
          <label for="region" class="form-card__field">
            <span class="form-card__field-label">Region</span>
            <input id="region" name="region" [(ngModel)]="control.formData.region" />
          </label>
          <label for="task_type" class="form-card__field">
            <span class="form-card__field-label">Task type</span>
            <input id="task_type" name="task_type" [(ngModel)]="control.formData.task_type" />
          </label>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="taskForm.invalid || control.saving">
              Create Agricultural Task
            </button>
            <a [routerLink]="['/agricultural_tasks']" class="btn-secondary">Back</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './agricultural-task-create.component.css'
})
export class AgriculturalTaskCreateComponent implements AgriculturalTaskCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskCreateViewState = initialControl;
  get control(): AgriculturalTaskCreateViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createAgriculturalTask(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    this.useCase.execute({
      ...fd,
      weather_dependency: fd.weather_dependency ?? undefined,
      skill_level: fd.skill_level ?? undefined,
      onSuccess: () => this.router.navigate(['/agricultural_tasks'])
    });
  }
}