import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  AgriculturalTaskListView,
  AgriculturalTaskListViewState
} from './agricultural-task-list.view';
import {
  AgriculturalTaskListPresenter,
  AGRICULTURAL_TASK_LIST_PROVIDERS
} from '../../../usecase/agricultural-tasks/agricultural-task-list.providers';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../../core/list-refresh/list-refresh-keys';

const initialControl: AgriculturalTaskListViewState = {
  loading: true,
  error: null,
  tasks: []
};

@Component({
  selector: 'app-agricultural-task-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...AGRICULTURAL_TASK_LIST_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'agricultural_tasks.index.title' | translate }}</h1>
        <p class="page-description">{{ 'agricultural_tasks.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <div class="section-card__header-actions">
            <a [routerLink]="['/agricultural_tasks', 'new']" class="btn-primary">
              {{ 'agricultural_tasks.index.new_agricultural_task' | translate }}
            </a>
          </div>
          <ul class="card-list" role="list">
            @for (task of control.tasks; track task.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/agricultural_tasks', task.id]" class="item-card__body">
                    <span class="item-card__title">{{ task.name }}</span>
                    @if (task.skill_level) {
                      <span class="item-card__meta">
                        {{ 'agricultural_tasks.index.skill_label' | translate }}: {{ task.skill_level }}
                      </span>
                    }
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/agricultural_tasks', task.id, 'edit']" class="btn-secondary">
                      {{ 'common.edit' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn-danger"
                      (click)="deleteTask(task.id)"
                      [attr.aria-label]="'common.delete' | translate"
                    >
                      {{ 'common.delete' | translate }}
                    </button>
                  </div>
                </article>
              </li>
            }
          </ul>
        }
      </section>
    </main>
  `,
  styleUrls: ['./agricultural-task-list.component.css']
})
export class AgriculturalTaskListComponent implements AgriculturalTaskListView, OnInit, OnDestroy {
  private readonly useCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly deleteUseCase = inject(DeleteAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly listRefreshBus = inject(ListRefreshBus);
  private unsubRefresh: (() => void) | null = null;

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
    this.unsubRefresh = this.listRefreshBus.onRefresh(LIST_REFRESH_CHANNEL.agriculturalTasks, () => this.refreshAfterUndo());
  }

  ngOnDestroy(): void {
    this.unsubRefresh?.();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute();
  }

  /** UNDO 後の再取得。ローディング表示にせず一覧を更新する。 */
  refreshAfterUndo(): void {
    this.useCase.execute();
  }

  deleteTask(taskId: number): void {
    this.deleteUseCase.execute({
      agriculturalTaskId: taskId,
      onSuccess: () => {},
      onAfterUndo: () => this.refreshAfterUndo()
    });
  }
}
