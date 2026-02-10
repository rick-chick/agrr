import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
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
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

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
  imports: [CommonModule, FormsModule, RouterLink, RegionSelectComponent, TranslateModule],
  providers: [
    AgriculturalTaskCreatePresenter,
    CreateAgriculturalTaskUseCase,
    { provide: CREATE_AGRICULTURAL_TASK_OUTPUT_PORT, useExisting: AgriculturalTaskCreatePresenter },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">
          {{ 'agricultural_tasks.new.title' | translate }}
        </h2>
        <form (ngSubmit)="createAgriculturalTask()" #taskForm="ngForm" class="form-card__form">
          <label for="name" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.name_label' | translate }}
            </span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label for="description" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.description_label' | translate }}
            </span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <label for="time_per_sqm" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.time_per_sqm_label' | translate }}
            </span>
            <input id="time_per_sqm" name="time_per_sqm" type="number" step="0.01" [(ngModel)]="control.formData.time_per_sqm" />
          </label>
          <label for="weather_dependency" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.weather_dependency_label' | translate }}
            </span>
            <select id="weather_dependency" name="weather_dependency" [(ngModel)]="control.formData.weather_dependency">
              <option value="low">{{ 'agricultural_tasks.show.weather_dependency_low' | translate }}</option>
              <option value="medium">{{ 'agricultural_tasks.show.weather_dependency_medium' | translate }}</option>
              <option value="high">{{ 'agricultural_tasks.show.weather_dependency_high' | translate }}</option>
            </select>
          </label>
          <label for="skill_level" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.skill_level_label' | translate }}
            </span>
            <select id="skill_level" name="skill_level" [(ngModel)]="control.formData.skill_level">
              <option value="beginner">{{ 'agricultural_tasks.show.skill_level_beginner' | translate }}</option>
              <option value="intermediate">{{ 'agricultural_tasks.show.skill_level_intermediate' | translate }}</option>
              <option value="advanced">{{ 'agricultural_tasks.show.skill_level_advanced' | translate }}</option>
            </select>
          </label>
          @if (auth.user()?.admin) {
            <app-region-select
              [region]="control.formData.region"
              (regionChange)="control.formData.region = $event"
            ></app-region-select>
          }
          <label for="task_type" class="form-card__field">
            <span class="form-card__field-label">
              {{ 'agricultural_tasks.form.task_type_label' | translate }}
            </span>
            <input id="task_type" name="task_type" [(ngModel)]="control.formData.task_type" />
          </label>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="taskForm.invalid || control.saving">
              {{ 'agricultural_tasks.form.submit_create' | translate }}
            </button>
            <a [routerLink]="['/agricultural_tasks']" class="btn-secondary">{{ 'common.back' | translate }}</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./agricultural-task-create.component.css']
})
export class AgriculturalTaskCreateComponent implements AgriculturalTaskCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskCreateViewState = initialControl;
  get control(): AgriculturalTaskCreateViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskCreateViewState) {
    this._control = this.applyUserRegionIfNeeded(value);
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.control = this.applyUserRegionIfNeeded(this.control);
  }

  createAgriculturalTask(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    const region = this.auth.user()?.admin ? fd.region : this.userRegion ?? fd.region;
    this.useCase.execute({
      ...fd,
      region,
      weather_dependency: fd.weather_dependency ?? undefined,
      skill_level: fd.skill_level ?? undefined,
      onSuccess: () => this.router.navigate(['/agricultural_tasks'])
    });
  }

  private get userRegion(): string | null {
    return (this.auth.user() as { region?: string | null } | null)?.region ?? null;
  }

  private applyUserRegionIfNeeded(
    control: AgriculturalTaskCreateViewState
  ): AgriculturalTaskCreateViewState {
    if (this.auth.user()?.admin) return control;
    const region = this.userRegion;
    if (!region || control.formData.region === region) return control;
    return { ...control, formData: { ...control.formData, region } };
  }
}