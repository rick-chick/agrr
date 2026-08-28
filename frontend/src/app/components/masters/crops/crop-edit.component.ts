import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { MasterLoadErrorPanelComponent } from '../master-load-error-panel/master-load-error-panel.component';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { CropEditView, CropEditViewState, CropEditFormData } from './crop-edit.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { UpdateCropUseCase } from '../../../usecase/crops/update-crop.usecase';
import {
  CropEditPresenter,
  CROP_EDIT_PROVIDERS
} from '../../../usecase/crops/crop-edit.providers';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import {
  formCardAriaDescribedbyForRequired,
  formCardAriaInvalidForRequired,
  formCardFieldErrorId,
  formCardShowsRequiredError
} from '../../../core/form-card-field-a11y';

const initialFormData: CropEditFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: [],
  groupsDisplay: '',
  is_reference: false,
  updated_at: null
};

function parseGroups(s: string): string[] {
  return (s || '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}

const initialControl: CropEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData,
  pendingErrorFlash: null,
  pendingSuccessFlash: null
};

@Component({
  selector: 'app-crop-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RegionSelectComponent, TranslateModule, MasterContextHeaderComponent, RouterLink, MasterLoadErrorPanelComponent],
  providers: [...CROP_EDIT_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        @if (!control.loading) {
          <h2 id="form-heading" class="form-card__title">{{ 'crops.edit.title' | translate:{ name: control.formData.name } }}</h2>
        } @else {
          <h2 id="form-heading" class="form-card__title">{{ 'common.loading' | translate }}</h2>
        }
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <app-master-load-error-panel
            [errorKey]="control.error"
            [listLink]="['/crops']"
            backLabelKey="crops.index.title"
            (retry)="reload()"
          />
        } @else {
          <form (ngSubmit)="updateCrop(cropForm)" #cropForm="ngForm" class="form-card__form">
            <label for="crop-name" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.name_label' | translate }}</span>
              <input
                id="crop-name"
                name="name"
                [(ngModel)]="control.formData.name"
                required
                [class.form-card__input--invalid]="showsRequiredError(formSubmitted, control.formData.name)"
                [attr.aria-invalid]="ariaInvalidForRequired(formSubmitted, control.formData.name)"
                [attr.aria-describedby]="ariaDescribedbyForRequired('crop-name', formSubmitted, control.formData.name)"
              />
              @if (showsRequiredError(formSubmitted, control.formData.name)) {
                <span [id]="fieldErrorId('crop-name')" class="form-card__field-error" role="alert">
                  {{ 'common.form.required_field' | translate }}
                </span>
              }
            </label>
            <label for="crop-variety" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.variety_label' | translate }}</span>
              <input id="crop-variety" name="variety" [(ngModel)]="control.formData.variety" />
            </label>
            <label for="crop-area-per-unit" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.area_per_unit_label' | translate }}</span>
              <input id="crop-area-per-unit" name="area_per_unit" type="number" step="0.01" [(ngModel)]="control.formData.area_per_unit" />
            </label>
            <label for="crop-revenue-per-area" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.revenue_per_area_label' | translate }}</span>
              <input id="crop-revenue-per-area" name="revenue_per_area" type="number" step="0.01" [(ngModel)]="control.formData.revenue_per_area" />
            </label>
            <label for="crop-groups" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.groups_label' | translate }}</span>
              <input id="crop-groups" name="groups" [(ngModel)]="control.formData.groupsDisplay" [placeholder]="'crops.form.groups_placeholder' | translate" />
            </label>
            @if (isAdmin) {
              <app-region-select
                id="crop-region"
                [region]="control.formData.region"
                (regionChange)="control.formData.region = $event"
              ></app-region-select>
            }
            @if (isAdmin) {
              <label class="form-card__field form-card__field--checkbox">
                <input type="checkbox" name="is_reference" [(ngModel)]="control.formData.is_reference" />
                <span class="form-card__field-label">{{ 'crops.form.is_reference_label' | translate }}</span>
              </label>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn btn-primary" [disabled]="control.saving">
                {{ 'crops.form.submit_update' | translate }}
              </button>
              <a [routerLink]="['/crops', cropId, 'setup_proposal']" class="btn btn-secondary">
                {{ 'crops.setup_proposal_import.action' | translate }}
              </a>
            </div>
          </form>
        }
      </section>
    </div>
  `,
  styleUrls: ['./crop-edit.component.css']
})
export class CropEditComponent implements CropEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly updateUseCase = inject(UpdateCropUseCase);
  private readonly presenter = inject(CropEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  formSubmitted = false;

  readonly fieldErrorId = formCardFieldErrorId;
  readonly showsRequiredError = formCardShowsRequiredError;
  readonly ariaInvalidForRequired = formCardAriaInvalidForRequired;
  readonly ariaDescribedbyForRequired = formCardAriaDescribedbyForRequired;

  private _control: CropEditViewState = initialControl;
  get control(): CropEditViewState {
    return this._control;
  }
  set control(value: CropEditViewState) {
    this._control = applyPendingFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  get isAdmin(): boolean {
    return this.auth.user()?.admin ?? false;
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'crops.index.title', routerLink: ['/crops'] }
    ];
    if (!this.control.loading && this.control.formData.name) {
      crumbs.push({
        label: this.control.formData.name,
        routerLink: ['/crops', this.cropId]
      });
    }
    crumbs.push({ labelKey: 'common.edit' });
    return crumbs;
  }

  get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.syncRegionWithCurrentUser();
    if (!this.cropId) {
      this.control = { ...initialControl, loading: false, error: 'crops.errors.invalid_id' };
      return;
    }
    this.reload();
  }

  reload(): void {
    if (!this.cropId) return;
    this.control = { ...this.control, loading: true, error: null };
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  updateCrop(form?: NgForm): void {
    this.formSubmitted = true;
    if (form?.invalid || this.control.saving) {
      if (form?.invalid) {
        for (const control of Object.values(form.controls)) {
          control.markAsTouched();
        }
      }
      return;
    }
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    const region = this.resolveRegionForSubmit();
    this.updateUseCase.execute({
      cropId: this.cropId,
      name: fd.name,
      variety: fd.variety,
      area_per_unit: fd.area_per_unit,
      revenue_per_area: fd.revenue_per_area,
      region,
      groups: parseGroups(fd.groupsDisplay),
      is_reference: fd.is_reference,
      updated_at: fd.updated_at,
      onSuccess: () => this.router.navigate(['/crops', this.cropId])
    });
  }

  private get currentUserRegion(): string | null {
    const user = this.auth.user() as { region?: string | null } | null;
    return user?.region ?? null;
  }

  private resolveRegionForSubmit(): string | null {
    if (this.isAdmin) return this.control.formData.region;
    return this.currentUserRegion ?? this.control.formData.region;
  }

  private syncRegionWithCurrentUser(): void {
    if (this.isAdmin) return;
    const region = this.currentUserRegion;
    if (!region || this.control.formData.region === region) return;
    this.control = {
      ...this.control,
      formData: {
        ...this.control.formData,
        region
      }
    };
  }
}
