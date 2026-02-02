import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { PestEditView, PestEditViewState, PestEditFormData } from './pest-edit.view';
import { LoadPestForEditUseCase } from '../../../usecase/pests/load-pest-for-edit.usecase';
import { UpdatePestUseCase } from '../../../usecase/pests/update-pest.usecase';
import { PestEditPresenter } from '../../../adapters/pests/pest-edit.presenter';
import { LOAD_PEST_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/pests/load-pest-for-edit.output-port';
import { UPDATE_PEST_OUTPUT_PORT } from '../../../usecase/pests/update-pest.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

const initialFormData: PestEditFormData = {
  name: '',
  name_scientific: null,
  family: null,
  order: null,
  description: null,
  occurrence_season: null,
  region: null
};

const initialControl: PestEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-pest-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    PestEditPresenter,
    LoadPestForEditUseCase,
    UpdatePestUseCase,
    { provide: LOAD_PEST_FOR_EDIT_OUTPUT_PORT, useExisting: PestEditPresenter },
    { provide: UPDATE_PEST_OUTPUT_PORT, useExisting: PestEditPresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Edit Pest</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else {
          <form (ngSubmit)="updatePest()" #pestForm="ngForm" class="form-card__form">
            <label class="form-card__field" for="name">
              <span class="form-card__field-label">Name</span>
              <input id="name" name="name" [(ngModel)]="control.formData.name" required />
            </label>
            <label class="form-card__field" for="name_scientific">
              <span class="form-card__field-label">Scientific Name</span>
              <input id="name_scientific" name="name_scientific" [(ngModel)]="control.formData.name_scientific" />
            </label>
            <label class="form-card__field" for="family">
              <span class="form-card__field-label">Family</span>
              <input id="family" name="family" [(ngModel)]="control.formData.family" />
            </label>
            <label class="form-card__field" for="order">
              <span class="form-card__field-label">Order</span>
              <input id="order" name="order" [(ngModel)]="control.formData.order" />
            </label>
            <label class="form-card__field" for="description">
              <span class="form-card__field-label">Description</span>
              <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
            </label>
            <label class="form-card__field" for="occurrence_season">
              <span class="form-card__field-label">Occurrence Season</span>
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
                {{ control.saving ? 'Updating...' : 'Update Pest' }}
              </button>
              <a [routerLink]="['/pests']" class="btn-secondary">Back</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./pest-edit.component.css']
})
export class PestEditComponent implements PestEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadPestForEditUseCase);
  private readonly updateUseCase = inject(UpdatePestUseCase);
  private readonly presenter = inject(PestEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestEditViewState = initialControl;
  get control(): PestEditViewState {
    return this._control;
  }
  set control(value: PestEditViewState) {
    this._control = this.applyUserRegion(value);
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.applyUserRegionToForm();
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pestId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid pest id.' };
      return;
    }
    this.load(pestId);
  }

  load(pestId: number): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({ pestId });
  }

  updatePest(): void {
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pestId || !this.control.formData.name.trim()) return;
    this.control = { ...this.control, saving: true };
    this.updateUseCase.execute({
      pestId,
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

  private applyUserRegion(value: PestEditViewState): PestEditViewState {
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