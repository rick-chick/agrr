import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { PestCreateView, PestCreateViewState, PestCreateFormData } from './pest-create.view';
import { CreatePestUseCase } from '../../../usecase/pests/create-pest.usecase';
import { PestCreatePresenter, PEST_CREATE_PROVIDERS } from '../../../usecase/pests/pest-create.providers';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialFormData: PestCreateFormData = {
  name: '',
  name_scientific: null,
  family: null,
  order: null,
  description: null,
  occurrence_season: null,
  region: null
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: PestCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-pest-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...PEST_CREATE_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'pests.new.title' | translate }}</h2>
        <form (ngSubmit)="createPest()" #pestForm="ngForm" class="form-card__form">
          <label class="form-card__field" for="name">
            <span class="form-card__field-label">{{ 'pests.form.name_label' | translate }}</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label class="form-card__field" for="name_scientific">
            <span class="form-card__field-label">{{ 'pests.form.name_scientific_label' | translate }}</span>
            <input id="name_scientific" name="name_scientific" [(ngModel)]="control.formData.name_scientific" />
          </label>
          <label class="form-card__field" for="family">
            <span class="form-card__field-label">{{ 'pests.form.family_label' | translate }}</span>
            <input id="family" name="family" [(ngModel)]="control.formData.family" />
          </label>
          <label class="form-card__field" for="order">
            <span class="form-card__field-label">{{ 'pests.form.order_label' | translate }}</span>
            <input id="order" name="order" [(ngModel)]="control.formData.order" />
          </label>
          <label class="form-card__field" for="description">
            <span class="form-card__field-label">{{ 'pests.form.description_label' | translate }}</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <label class="form-card__field" for="occurrence_season">
            <span class="form-card__field-label">{{ 'pests.form.occurrence_season_label' | translate }}</span>
            <input id="occurrence_season" name="occurrence_season" [(ngModel)]="control.formData.occurrence_season" />
          </label>
          @if (auth.user()?.admin) {
            <app-region-select
              [region]="control.formData.region"
              (regionChange)="control.formData.region = $event"
            ></app-region-select>
          }
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="pestForm.invalid || control.saving">
              {{ control.saving ? ('common.creating' | translate) : ('pests.form.submit_create' | translate) }}
            </button>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./pest-create.component.css']
})
export class PestCreateComponent implements PestCreateView, OnInit {
  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'pests.index.title', routerLink: ['/pests'] },
      { labelKey: 'pests.new.title' }
    ];
  }

  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreatePestUseCase);
  private readonly presenter = inject(PestCreatePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestCreateViewState = initialControl;
  get control(): PestCreateViewState {
    return this._control;
  }
  set control(value: PestCreateViewState) {
    const next = applyPendingErrorFlashViewEffects(this.applyUserRegion(value), {
      flash: this.flashMessage
    });
    this._control = next;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.applyUserRegionToForm();
  }

  createPest(): void {
    if (!this.control.formData.name.trim()) return;
    this.control = { ...this.control, saving: true };
    this.useCase.execute({
      ...this.control.formData,
      region: this.resolveRegion(this.control.formData.region),
      onSuccess: (pest) => this.router.navigate(['/pests', pest.id])
    });
  }

  private applyUserRegionToForm(): void {
    if (this.auth.user()?.admin) return;
    const region = this.userRegion;
    if (!region || this.control.formData.region === region) return;
    this.control = {
      ...this.control,
      formData: { ...this.control.formData, region }
    };
  }

  private resolveRegion(formRegion: string | null): string | null {
    if (this.auth.user()?.admin) return formRegion;
    return this.userRegion ?? formRegion;
  }

  private applyUserRegion(value: PestCreateViewState): PestCreateViewState {
    if (this.auth.user()?.admin) return value;
    const region = this.userRegion;
    if (!region || value.formData.region === region) return value;
    return {
      ...value,
      formData: { ...value.formData, region }
    };
  }

  private get userRegion(): string | null {
    const user = this.auth.user() as { region?: string | null } | null;
    return user?.region ?? null;
  }
}