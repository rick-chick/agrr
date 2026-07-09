import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
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
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialFormData: CropEditFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: [],
  groupsDisplay: '',
  is_reference: false
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
  imports: [CommonModule, FormsModule, RegionSelectComponent, TranslateModule, MasterContextHeaderComponent],
  providers: [...CROP_EDIT_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        @if (!control.loading) {
          <h2 id="form-heading" class="form-card__title">{{ 'crops.edit.title' | translate:{ name: control.formData.name } }}</h2>
        } @else {
          <h2 id="form-heading" class="form-card__title">{{ 'common.loading' | translate }}</h2>
        }
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateCrop()" #cropForm="ngForm" class="form-card__form">
            <label for="crop-name" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.name_label' | translate }}</span>
              <input id="crop-name" name="name" [(ngModel)]="control.formData.name" required />
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
              <button type="submit" class="btn-primary" [disabled]="cropForm.invalid || control.saving">
                {{ 'crops.form.submit_update' | translate }}
              </button>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./crop-edit.component.css']
})
export class CropEditComponent implements CropEditView, OnInit {
  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'crops.index.title', routerLink: ['/crops'] }
    ];
    if (!this.control.loading && this.control.formData.name) {
      crumbs.push({ label: this.control.formData.name, routerLink: ['/crops', this.cropId] });
    }
    crumbs.push({ labelKey: 'common.edit' });
    return crumbs;
  }

  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly updateUseCase = inject(UpdateCropUseCase);
  private readonly presenter = inject(CropEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

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

  private get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.syncRegionWithCurrentUser();
    if (!this.cropId) {
      this.control = { ...initialControl, loading: false, error: this.translate.instant('crops.errors.invalid_id') };
      return;
    }
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  updateCrop(): void {
    if (this.control.saving) return;
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
