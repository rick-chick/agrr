import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { FertilizeEditView, FertilizeEditViewState, FertilizeEditFormData } from './fertilize-edit.view';
import { LoadFertilizeForEditUseCase } from '../../../usecase/fertilizes/load-fertilize-for-edit.usecase';
import { UpdateFertilizeUseCase } from '../../../usecase/fertilizes/update-fertilize.usecase';
import { FertilizeEditPresenter } from '../../../adapters/fertilizes/fertilize-edit.presenter';
import { LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/fertilizes/load-fertilize-for-edit.output-port';
import { UPDATE_FERTILIZE_OUTPUT_PORT } from '../../../usecase/fertilizes/update-fertilize.output-port';
import { FERTILIZE_GATEWAY } from '../../../usecase/fertilizes/fertilize-gateway';
import { FertilizeApiGateway } from '../../../adapters/fertilizes/fertilize-api.gateway';

const initialFormData: FertilizeEditFormData = {
  name: '',
  n: null,
  p: null,
  k: null,
  description: null,
  package_size: null,
  region: null
};

const initialControl: FertilizeEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-fertilize-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    FertilizeEditPresenter,
    LoadFertilizeForEditUseCase,
    UpdateFertilizeUseCase,
    { provide: LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
    { provide: UPDATE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
    { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">
          {{ 'fertilizes.edit.title' | translate:{ name: control.formData.name } }}
        </h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateFertilize()" #fertilizeForm="ngForm" class="form-card__form">
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
              <button type="submit" class="btn-primary" [disabled]="fertilizeForm.invalid || control.saving">
                {{ 'fertilizes.form.submit_update' | translate }}
              </button>
              <a routerLink="/fertilizes" class="btn-secondary">{{ 'fertilizes.show.back_to_list' | translate }}</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./fertilize-edit.component.css']
})
export class FertilizeEditComponent implements FertilizeEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFertilizeForEditUseCase);
  private readonly updateUseCase = inject(UpdateFertilizeUseCase);
  private readonly presenter = inject(FertilizeEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeEditViewState = initialControl;
  get control(): FertilizeEditViewState {
    return this._control;
  }
  set control(value: FertilizeEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get fertilizeId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.fertilizeId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid fertilize id.' };
      return;
    }
    this.loadUseCase.execute({ fertilizeId: this.fertilizeId });
  }

  updateFertilize(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const region = this.resolveRegionForSubmit(this.control.formData.region);
    this.updateUseCase.execute({
      fertilizeId: this.fertilizeId,
      ...this.control.formData,
      region,
      onSuccess: () => this.router.navigate(['/fertilizes'])
    });
  }

  private resolveRegionForSubmit(currentRegion: string | null): string | null {
    if (this.auth.user()?.admin) return currentRegion;
    const userRegion = (this.auth.user() as { region?: string | null } | null)?.region ?? null;
    return userRegion ?? currentRegion;
  }
}
