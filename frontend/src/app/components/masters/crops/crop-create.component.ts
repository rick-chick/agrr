import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { CropCreateView, CropCreateViewState, CropCreateFormData } from './crop-create.view';
import { CreateCropUseCase } from '../../../usecase/crops/create-crop.usecase';
import { CropCreatePresenter } from '../../../adapters/crops/crop-create.presenter';
import { CREATE_CROP_OUTPUT_PORT } from '../../../usecase/crops/create-crop.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';

const initialFormData: CropCreateFormData = {
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

const initialControl: CropCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-crop-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    CropCreatePresenter,
    CreateCropUseCase,
    { provide: CREATE_CROP_OUTPUT_PORT, useExisting: CropCreatePresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'crops.new.title' | translate }}</h2>
        <form (ngSubmit)="createCrop()" #cropForm="ngForm" class="form-card__form">
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
              {{ 'crops.form.submit_create' | translate }}
            </button>
            <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./crop-create.component.css']
})
export class CropCreateComponent implements CropCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateCropUseCase);
  private readonly presenter = inject(CropCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropCreateViewState = initialControl;
  get control(): CropCreateViewState {
    return this._control;
  }
  set control(value: CropCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  get isAdmin(): boolean {
    return this.auth.user()?.admin ?? false;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.syncRegionWithCurrentUser();
  }

  createCrop(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    const region = this.resolveRegionForSubmit();
    this.useCase.execute({
      name: fd.name,
      variety: fd.variety,
      area_per_unit: fd.area_per_unit,
      revenue_per_area: fd.revenue_per_area,
      region,
      groups: parseGroups(fd.groupsDisplay),
      is_reference: fd.is_reference,
      onSuccess: () => this.router.navigate(['/crops'])
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
