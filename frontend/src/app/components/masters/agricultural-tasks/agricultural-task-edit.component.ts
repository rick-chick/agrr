import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import {
  AgriculturalTaskEditView,
  AgriculturalTaskEditViewState,
  AgriculturalTaskEditFormData
} from './agricultural-task-edit.view';
import { LoadAgriculturalTaskForEditUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-for-edit.usecase';
import { UpdateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/update-agricultural-task.usecase';
import { AgriculturalTaskEditPresenter } from '../../../adapters/agricultural-tasks/agricultural-task-edit.presenter';
import { LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/load-agricultural-task-for-edit.output-port';
import { UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/update-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY } from '../../../usecase/agricultural-tasks/agricultural-task-gateway';
import { AgriculturalTaskApiGateway } from '../../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

const initialFormData: AgriculturalTaskEditFormData = {
  name: '',
  description: null,
  time_per_sqm: null,
  weather_dependency: null,
  required_tools: [],
  skill_level: null,
  region: null,
  task_type: null
};

const initialControl: AgriculturalTaskEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-agricultural-task-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    AgriculturalTaskEditPresenter,
    LoadAgriculturalTaskForEditUseCase,
    UpdateAgriculturalTaskUseCase,
    { provide: LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT, useExisting: AgriculturalTaskEditPresenter },
    { provide: UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT, useExisting: AgriculturalTaskEditPresenter },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Edit Agricultural Task</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else {
          <form (ngSubmit)="updateAgriculturalTask()" #taskForm="ngForm" class="form-card__form">
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
            @if (auth.user()?.admin) {
              <app-region-select
                [region]="control.formData.region"
                (regionChange)="control.formData.region = $event"
              ></app-region-select>
            }
            <label for="task_type" class="form-card__field">
              <span class="form-card__field-label">Task type</span>
              <input id="task_type" name="task_type" [(ngModel)]="control.formData.task_type" />
            </label>
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="taskForm.invalid || control.saving">
                Update Agricultural Task
              </button>
              <a [routerLink]="['/agricultural_tasks']" class="btn-secondary">Back</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./agricultural-task-edit.component.css']
})
export class AgriculturalTaskEditComponent implements AgriculturalTaskEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadAgriculturalTaskForEditUseCase);
  private readonly updateUseCase = inject(UpdateAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskEditViewState = initialControl;
  get control(): AgriculturalTaskEditViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskEditViewState) {
    this._control = this.applyUserRegionIfNeeded(value);
    this.cdr.markForCheck();
  }

  private get agriculturalTaskId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.control = this.applyUserRegionIfNeeded(this.control);
    if (!this.agriculturalTaskId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid agricultural task id.' };
      return;
    }
    this.loadUseCase.execute({ agriculturalTaskId: this.agriculturalTaskId });
  }

  updateAgriculturalTask(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    const region = this.auth.user()?.admin ? fd.region : this.userRegion ?? fd.region;
    this.updateUseCase.execute({
      agriculturalTaskId: this.agriculturalTaskId,
      ...fd,
      region,
      weather_dependency: fd.weather_dependency ?? undefined,
      skill_level: fd.skill_level ?? undefined,
      onSuccess: () => this.router.navigate(['/agricultural_tasks', this.agriculturalTaskId])
    });
  }

  private get userRegion(): string | null {
    return (this.auth.user() as { region?: string | null } | null)?.region ?? null;
  }

  private applyUserRegionIfNeeded(
    control: AgriculturalTaskEditViewState
  ): AgriculturalTaskEditViewState {
    if (this.auth.user()?.admin) return control;
    const region = this.userRegion;
    if (!region || control.formData.region === region) return control;
    return { ...control, formData: { ...control.formData, region } };
  }
}