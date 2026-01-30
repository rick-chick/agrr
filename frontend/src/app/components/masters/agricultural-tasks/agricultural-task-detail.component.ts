import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  AgriculturalTaskDetailView,
  AgriculturalTaskDetailViewState
} from './agricultural-task-detail.view';
import { LoadAgriculturalTaskDetailUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-detail.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { AgriculturalTaskDetailPresenter } from '../../../adapters/agricultural-tasks/agricultural-task-detail.presenter';
import { LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/load-agricultural-task-detail.output-port';
import { DELETE_AGRICULTURAL_TASK_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/delete-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY } from '../../../usecase/agricultural-tasks/agricultural-task-gateway';
import { AgriculturalTaskApiGateway } from '../../../adapters/agricultural-tasks/agricultural-task-api.gateway';

const initialControl: AgriculturalTaskDetailViewState = {
  loading: true,
  error: null,
  agriculturalTask: null
};

@Component({
  selector: 'app-agricultural-task-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    AgriculturalTaskDetailPresenter,
    LoadAgriculturalTaskDetailUseCase,
    DeleteAgriculturalTaskUseCase,
    { provide: LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT, useExisting: AgriculturalTaskDetailPresenter },
    { provide: DELETE_AGRICULTURAL_TASK_OUTPUT_PORT, useExisting: AgriculturalTaskDetailPresenter },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">Loading...</p>
      } @else if (control.error) {
        <p class="master-error">{{ control.error }}</p>
      } @else if (control.agriculturalTask) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.agriculturalTask.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">Name</dt>
              <dd class="detail-row__value">{{ control.agriculturalTask.name }}</dd>
            </div>
            @if (control.agriculturalTask.description) {
              <div class="detail-row">
                <dt class="detail-row__term">Description</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.description }}</dd>
              </div>
            }
            @if (control.agriculturalTask.time_per_sqm) {
              <div class="detail-row">
                <dt class="detail-row__term">Time per sqm</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.time_per_sqm }} hours</dd>
              </div>
            }
            @if (control.agriculturalTask.weather_dependency) {
              <div class="detail-row">
                <dt class="detail-row__term">Weather dependency</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.weather_dependency }}</dd>
              </div>
            }
            @if (control.agriculturalTask.skill_level) {
              <div class="detail-row">
                <dt class="detail-row__term">Skill level</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.skill_level }}</dd>
              </div>
            }
            @if (control.agriculturalTask.region) {
              <div class="detail-row">
                <dt class="detail-row__term">Region</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.region }}</dd>
              </div>
            }
            @if (control.agriculturalTask.task_type) {
              <div class="detail-row">
                <dt class="detail-row__term">Task type</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.task_type }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/agricultural_tasks']" class="btn-secondary">Back</a>
            <a [routerLink]="['/agricultural_tasks', control.agriculturalTask.id, 'edit']" class="btn-secondary">Edit</a>
            <button type="button" class="btn-danger" (click)="deleteAgriculturalTask()">Delete</button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrl: './agricultural-task-detail.component.css'
})
export class AgriculturalTaskDetailComponent implements AgriculturalTaskDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadAgriculturalTaskDetailUseCase);
  private readonly deleteUseCase = inject(DeleteAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskDetailViewState = initialControl;
  get control(): AgriculturalTaskDetailViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const agriculturalTaskId = Number(this.route.snapshot.paramMap.get('id'));
    if (!agriculturalTaskId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid agricultural task id.' };
      return;
    }
    this.load(agriculturalTaskId);
  }

  load(agriculturalTaskId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ agriculturalTaskId });
  }

  deleteAgriculturalTask(): void {
    if (!this.control.agriculturalTask) return;
    this.deleteUseCase.execute({
      agriculturalTaskId: this.control.agriculturalTask.id,
      onSuccess: () => this.router.navigate(['/agricultural_tasks'])
    });
  }
}