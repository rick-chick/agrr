import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
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
import { FormFieldComponent } from '../../shared/form-field/form-field.component';

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
  imports: [CommonModule, FormsModule, TranslateModule, RegionSelectComponent, FormFieldComponent, MasterContextHeaderComponent],
  providers: [...FERTILIZE_CREATE_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'fertilizes.new.title' | translate }}</h2>
        <form (ngSubmit)="createFertilize(fertilizeForm)" #fertilizeForm="ngForm" class="form-card__form">
          <app-form-field
            inputId="name"
            name="name"
            labelKey="fertilizes.form.name_label"
            [required]="true"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.name"
          />
          @if (auth.user()?.admin) {
            <app-region-select
              [region]="control.formData.region"
              (regionChange)="control.formData.region = $event"
            ></app-region-select>
          }
          <app-form-field
            inputId="n"
            name="n"
            type="number"
            labelKey="fertilizes.form.n_label"
            step="0.01"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.n"
          />
          <app-form-field
            inputId="p"
            name="p"
            type="number"
            labelKey="fertilizes.form.p_label"
            step="0.01"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.p"
          />
          <app-form-field
            inputId="k"
            name="k"
            type="number"
            labelKey="fertilizes.form.k_label"
            step="0.01"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.k"
          />
          <app-form-field
            inputId="package_size"
            name="package_size"
            type="number"
            labelKey="fertilizes.form.package_size_label"
            step="0.01"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.package_size"
          />
          <app-form-field
            inputId="description"
            name="description"
            type="textarea"
            labelKey="fertilizes.form.description_label"
            [formSubmitted]="formSubmitted"
            [(value)]="control.formData.description"
          />
          <div class="form-card__actions">
            <button type="submit" class="btn btn-primary" [disabled]="control.saving">
              {{ 'fertilizes.form.submit_create' | translate }}
            </button>
          </div>
        </form>
      </section>
    </div>
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

  formSubmitted = false;

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

  createFertilize(form?: NgForm): void {
    this.formSubmitted = true;
    if (form?.invalid) {
      for (const control of Object.values(form.controls)) {
        control.markAsTouched();
      }
      return;
    }
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
