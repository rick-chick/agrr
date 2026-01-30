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
    <div class="content-card">
      <div class="page-header">
        <a [routerLink]="['/agricultural_tasks']" class="btn btn-white">Back</a>
        @if (control.agriculturalTask) {
          <a [routerLink]="['/agricultural_tasks', control.agriculturalTask.id, 'edit']" class="btn btn-white">Edit</a>
          <button type="button" class="btn btn-danger" (click)="deleteAgriculturalTask()">Delete</button>
        }
      </div>

      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.agriculturalTask) {
        <h2 class="page-title">{{ control.agriculturalTask.name }}</h2>
        <section class="info-section">
          <h3>Name</h3>
          <p>{{ control.agriculturalTask.name }}</p>
          <h3 *ngIf="control.agriculturalTask.description">Description</h3>
          <p *ngIf="control.agriculturalTask.description">{{ control.agriculturalTask.description }}</p>
          <h3 *ngIf="control.agriculturalTask.time_per_sqm">Time per sqm</h3>
          <p *ngIf="control.agriculturalTask.time_per_sqm">{{ control.agriculturalTask.time_per_sqm }} hours</p>
          <h3 *ngIf="control.agriculturalTask.weather_dependency">Weather dependency</h3>
          <p *ngIf="control.agriculturalTask.weather_dependency">{{ control.agriculturalTask.weather_dependency }}</p>
          <h3 *ngIf="control.agriculturalTask.skill_level">Skill level</h3>
          <p *ngIf="control.agriculturalTask.skill_level">{{ control.agriculturalTask.skill_level }}</p>
          <h3 *ngIf="control.agriculturalTask.region">Region</h3>
          <p *ngIf="control.agriculturalTask.region">{{ control.agriculturalTask.region }}</p>
          <h3 *ngIf="control.agriculturalTask.task_type">Task type</h3>
          <p *ngIf="control.agriculturalTask.task_type">{{ control.agriculturalTask.task_type }}</p>
        </section>
      }
    </div>
  `,
  styles: [`
    .info-section {
      margin-bottom: 2rem;
    }
  `]
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