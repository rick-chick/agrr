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
    <section class="page">
      <h2>Agricultural Tasks</h2>
      <a [routerLink]="['/agricultural_tasks', 'new']" class="btn btn-primary">New Agricultural Task</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <div class="task-list">
          @for (task of control.tasks; track task.id) {
            <div class="task-item">
              <a [routerLink]="['/agricultural_tasks', task.id]" class="task-link">
                <div class="task-name">{{ task.name }}</div>
                <div class="task-info" *ngIf="task.skill_level">Skill: {{ task.skill_level }}</div>
              </a>
              <div class="task-actions">
                <a [routerLink]="['/agricultural_tasks', task.id, 'edit']" class="btn btn-sm">Edit</a>
                <button type="button" class="btn btn-sm btn-danger" (click)="deleteTask(task.id)">Delete</button>
              </div>
            </div>
          }
        </div>
      }
    </section>
  `,
  styles: [`
    .task-list {
      margin-top: 1rem;
    }
    .task-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 1rem;
      border: 1px solid #ddd;
      border-radius: 4px;
      margin-bottom: 0.5rem;
      background: #f9f9f9;
    }
    .task-link {
      flex: 1;
      text-decoration: none;
      color: inherit;
    }
    .task-link:hover {
      text-decoration: underline;
    }
    .task-name {
      font-weight: bold;
    }
    .task-info {
      font-size: 0.9em;
      color: #666;
    }
    .task-actions {
      display: flex;
      gap: 0.5rem;
    }
    .btn {
      padding: 0.5rem 1rem;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      text-decoration: none;
      display: inline-block;
    }
    .btn-primary {
      background: #007bff;
      color: white;
    }
    .btn-sm {
      padding: 0.25rem 0.5rem;
      font-size: 0.875rem;
    }
    .btn-danger {
      background: #dc3545;
      color: white;
    }
  `],
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
