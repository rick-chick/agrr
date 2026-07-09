import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import {
  AgriculturalTaskEditView,
  AgriculturalTaskEditViewState,
  AgriculturalTaskEditFormData
} from './agricultural-task-edit.view';
import { LoadAgriculturalTaskForEditUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-for-edit.usecase';
import { UpdateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/update-agricultural-task.usecase';
import {
  AgriculturalTaskEditPresenter,
  AGRICULTURAL_TASK_EDIT_PROVIDERS
} from '../../../usecase/agricultural-tasks/agricultural-task-edit.providers';
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

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: AgriculturalTaskEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-agricultural-task-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...AGRICULTURAL_TASK_EDIT_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">
          {{
            'agricultural_tasks.edit.title'
              | translate: { name: control.formData.name || ('agricultural_tasks.edit.title_default' | translate) }
          }}
        </h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateAgriculturalTask()" #taskForm="ngForm" class="form-card__form">
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
                {{ 'agricultural_tasks.form.submit_update' | translate }}
              </button>
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
  private readonly translate = inject(TranslateService);
  private readonly loadUseCase = inject(LoadAgriculturalTaskForEditUseCase);
  private readonly updateUseCase = inject(UpdateAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskEditViewState = initialControl;
  get control(): AgriculturalTaskEditViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskEditViewState) {
    const next = applyPendingErrorFlashViewEffects(this.applyUserRegionIfNeeded(value), {
      flash: this.flashMessage
    });
    this._control = next;
    this.cdr.markForCheck();
  }

  private get agriculturalTaskId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'agricultural_tasks.index.title', routerLink: ['/agricultural_tasks'] }
    ];
    if (!this.control.loading && this.control.formData.name) {
      crumbs.push({
        label: this.control.formData.name,
        routerLink: ['/agricultural_tasks', this.agriculturalTaskId]
      });
    }
    crumbs.push({ labelKey: 'common.edit' });
    return crumbs;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.control = this.applyUserRegionIfNeeded(this.control);
    if (!this.agriculturalTaskId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('agricultural_tasks.errors.invalid_id')
      };
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