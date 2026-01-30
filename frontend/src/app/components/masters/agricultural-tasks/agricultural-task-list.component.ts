import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import {
  AgriculturalTaskListView,
  AgriculturalTaskListViewState
} from './agricultural-task-list.view';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { AgriculturalTaskListPresenter } from '../../../adapters/agricultural-tasks/agricultural-task-list.presenter';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { DELETE_AGRICULTURAL_TASK_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/delete-agricultural-task.output-port';
import { AGRICULTURAL_TASK_GATEWAY } from '../../../usecase/agricultural-tasks/agricultural-task-gateway';
import { AgriculturalTaskApiGateway } from '../../../adapters/agricultural-tasks/agricultural-task-api.gateway';

const initialControl: AgriculturalTaskListViewState = {
  loading: true,
  error: null,
  tasks: []
};

@Component({
  selector: 'app-agricultural-task-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    AgriculturalTaskListPresenter,
    LoadAgriculturalTaskListUseCase,
    DeleteAgriculturalTaskUseCase,
    {
      provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT,
      useExisting: AgriculturalTaskListPresenter
    },
    {
      provide: DELETE_AGRICULTURAL_TASK_OUTPUT_PORT,
      useExisting: AgriculturalTaskListPresenter
    },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 class="page-title">Agricultural Tasks</h1>
        <p class="page-description">Manage agricultural tasks.</p>
      </header>
      <section class="section-card" aria-labelledby="section-list-heading">
        <h2 id="section-list-heading" class="section-title">Task list</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="master-error">{{ control.error }}</p>
        } @else {
          <a [routerLink]="['/agricultural_tasks', 'new']" class="btn-primary">New Agricultural Task</a>
          <ul class="card-list" role="list">
            @for (task of control.tasks; track task.id) {
              <li class="card-list__item">
                <a [routerLink]="['/agricultural_tasks', task.id]" class="item-card">
                  <span class="item-card__title">{{ task.name }}</span>
                  @if (task.skill_level) {
                    <span class="item-card__meta">Skill: {{ task.skill_level }}</span>
                  }
                </a>
                <div class="list-item-actions">
                  <a [routerLink]="['/agricultural_tasks', task.id, 'edit']" class="btn-secondary btn-sm">Edit</a>
                  <button type="button" class="btn-danger btn-sm" (click)="deleteTask(task.id)">Delete</button>
                </div>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrl: './agricultural-task-list.component.css'
})
export class AgriculturalTaskListComponent implements AgriculturalTaskListView, OnInit {
  private readonly useCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly deleteUseCase = inject(DeleteAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskListViewState = initialControl;
  get control(): AgriculturalTaskListViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskListViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute();
  }

  deleteTask(taskId: number): void {
    this.deleteUseCase.execute({
      agriculturalTaskId: taskId,
      onSuccess: () => {},
      onAfterUndo: () => this.load()
    });
  }
}
