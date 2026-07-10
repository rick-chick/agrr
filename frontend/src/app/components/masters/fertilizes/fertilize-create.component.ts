import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { FertilizeCreateView, FertilizeCreateViewState, FertilizeCreateFormData } from './fertilize-create.view';
import { CreateFertilizeUseCase } from '../../../usecase/fertilizes/create-fertilize.usecase';
import {
  FertilizeCreatePresenter,
  FERTILIZE_CREATE_PROVIDERS
} from '../../../usecase/fertilizes/fertilize-create.providers';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

const initialFormData: FertilizeCreateFormData = {
  name: '',
  n: null,
  p: null,
  k: null,
  description: null,
  package_size: null,
  region: null
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: FertilizeCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-fertilize-create',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...FERTILIZE_CREATE_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'fertilizes.new.title' | translate }}</h2>
        <form (ngSubmit)="createFertilize()" #fertilizeForm="ngForm" class="form-card__form">
          <label for="name" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.name_label' | translate }}</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          @if (auth.user()?.admin) {
            <app-region-select
              [region]="control.formData.region"
              (regionChange)="control.formData.region = $event"
            ></app-region-select>
          }
          <label for="n" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.n_label' | translate }}</span>
            <input id="n" name="n" type="number" step="0.01" [(ngModel)]="control.formData.n" />
          </label>
          <label for="p" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.p_label' | translate }}</span>
            <input id="p" name="p" type="number" step="0.01" [(ngModel)]="control.formData.p" />
          </label>
          <label for="k" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.k_label' | translate }}</span>
            <input id="k" name="k" type="number" step="0.01" [(ngModel)]="control.formData.k" />
          </label>
          <label for="package_size" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.package_size_label' | translate }}</span>
            <input id="package_size" name="package_size" type="number" step="0.01" [(ngModel)]="control.formData.package_size" />
          </label>
          <label for="description" class="form-card__field">
            <span class="form-card__field-label">{{ 'fertilizes.form.description_label' | translate }}</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <div class="form-card__actions">
            <button type="submit" class="btn btn-primary" [disabled]="fertilizeForm.invalid || control.saving">
              {{ 'fertilizes.form.submit_create' | translate }}
            </button>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./fertilize-create.component.css']
})
export class FertilizeCreateComponent implements FertilizeCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFertilizeUseCase);
  private readonly presenter = inject(FertilizeCreatePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeCreateViewState = initialControl;
  get control(): FertilizeCreateViewState {
    return this._control;
  }
  set control(value: FertilizeCreateViewState) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'fertilizes.index.title', routerLink: ['/fertilizes'] },
      { labelKey: 'fertilizes.new.title' }
    ];
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createFertilize(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const userRegion = (this.auth.user() as { region?: string | null } | null)?.region ?? null;
    const isAdmin = this.auth.user()?.admin ?? false;
    this.useCase.execute({
      ...this.control.formData,
      region: isAdmin ? this.control.formData.region : userRegion,
      onSuccess: () => this.router.navigate(['/fertilizes'])
    });
  }
}
