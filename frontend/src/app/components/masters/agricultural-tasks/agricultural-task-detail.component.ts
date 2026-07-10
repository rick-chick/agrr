import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import {
  AgriculturalTaskDetailView,
  AgriculturalTaskDetailViewState
} from './agricultural-task-detail.view';
import { LoadAgriculturalTaskDetailUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-detail.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import {
  AgriculturalTaskDetailPresenter,
  AGRICULTURAL_TASK_DETAIL_PROVIDERS
} from '../../../usecase/agricultural-tasks/agricultural-task-detail.providers';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialControl: AgriculturalTaskDetailViewState = {
  loading: true,
  error: null,
  agriculturalTask: null,
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-agricultural-task-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, MasterContextHeaderComponent],
  providers: [...AGRICULTURAL_TASK_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.agriculturalTask) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.agriculturalTask.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'agricultural_tasks.show.name' | translate }}</dt>
              <dd class="detail-row__value">{{ control.agriculturalTask.name }}</dd>
            </div>
            @if (control.agriculturalTask.description) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.description' | translate }}</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.description }}</dd>
              </div>
            }
            @if (control.agriculturalTask.time_per_sqm) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.time_per_sqm' | translate }}</dt>
                <dd class="detail-row__value">
                  {{ control.agriculturalTask.time_per_sqm }} {{ 'agricultural_tasks.show.hours_suffix' | translate }}
                </dd>
              </div>
            }
            @if (control.agriculturalTask.weather_dependency) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.weather_dependency' | translate }}</dt>
                <dd class="detail-row__value">
                  {{ ('agricultural_tasks.show.weather_dependency_' + control.agriculturalTask.weather_dependency) | translate }}
                </dd>
              </div>
            }
            @if (control.agriculturalTask.skill_level) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.skill_level' | translate }}</dt>
                <dd class="detail-row__value">
                  {{ ('agricultural_tasks.show.skill_level_' + control.agriculturalTask.skill_level) | translate }}
                </dd>
              </div>
            }
            @if (control.agriculturalTask.region) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.region' | translate }}</dt>
                <dd class="detail-row__value">{{ 'agricultural_tasks.form.region_' + control.agriculturalTask.region | translate }}</dd>
              </div>
            }
            @if (control.agriculturalTask.task_type) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'agricultural_tasks.show.task_type' | translate }}</dt>
                <dd class="detail-row__value">{{ control.agriculturalTask.task_type }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/agricultural_tasks', control.agriculturalTask.id, 'edit']" class="btn btn-primary">
              {{ 'agricultural_tasks.show.edit' | translate }}
            </a>
            <button type="button" class="btn btn-danger" (click)="deleteAgriculturalTask()">
              {{ 'agricultural_tasks.show.delete' | translate }}
            </button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./agricultural-task-detail.component.css']
})
export class AgriculturalTaskDetailComponent implements AgriculturalTaskDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly useCase = inject(LoadAgriculturalTaskDetailUseCase);
  private readonly deleteUseCase = inject(DeleteAgriculturalTaskUseCase);
  private readonly presenter = inject(AgriculturalTaskDetailPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'agricultural_tasks.index.title', routerLink: ['/agricultural_tasks'] }
    ];
    if (this.control.agriculturalTask) {
      crumbs.push({ label: this.control.agriculturalTask.name });
    }
    return crumbs;
  }

  private _control: AgriculturalTaskDetailViewState = initialControl;
  get control(): AgriculturalTaskDetailViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskDetailViewState) {
    const next = applyPendingUndoToastViewEffects(
      applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage }),
      { toast: this.undoToast }
    );
    this._control = next;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const agriculturalTaskId = Number(this.route.snapshot.paramMap.get('id'));
    if (!agriculturalTaskId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('agricultural_tasks.errors.invalid_id')
      };
      return;
    }
    this.load(agriculturalTaskId);
  }

  load(agriculturalTaskId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ agriculturalTaskId });
  }

  reload(): void {
    const agriculturalTaskId = Number(this.route.snapshot.paramMap.get('id'));
    if (agriculturalTaskId) this.load(agriculturalTaskId);
  }

  deleteAgriculturalTask(): void {
    if (!this.control.agriculturalTask) return;
    this.deleteUseCase.execute({
      agriculturalTaskId: this.control.agriculturalTask.id,
      onSuccess: () => this.router.navigate(['/agricultural_tasks'])
    });
  }
}