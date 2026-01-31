import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropDetailView, CropDetailViewState } from './crop-detail.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { CropDetailPresenter } from '../../../adapters/crops/crop-detail.presenter';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from '../../../usecase/crops/load-crop-detail.output-port';
import { DELETE_CROP_OUTPUT_PORT } from '../../../usecase/crops/delete-crop.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';

const initialControl: CropDetailViewState = {
  loading: true,
  error: null,
  crop: null
};

@Component({
  selector: 'app-crop-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    CropDetailPresenter,
    LoadCropDetailUseCase,
    DeleteCropUseCase,
    { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropDetailPresenter },
    { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropDetailPresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.crop) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.crop.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'crops.show.name' | translate }}</dt>
              <dd class="detail-row__value">{{ control.crop.name }}</dd>
            </div>
            @if (control.crop.variety) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.variety' | translate }}</dt>
                <dd class="detail-row__value">{{ control.crop.variety }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/crops', control.crop.id, 'edit']" class="btn-primary">{{ 'common.edit' | translate }}</a>
            <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deleteCrop()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>

        @if (control.crop.crop_stages?.length) {
          <section class="section-card" aria-labelledby="stages-heading">
            <h2 id="stages-heading" class="section-title">{{ 'crops.show.stages_title' | translate }}</h2>
            <div class="stages-grid">
              @for (stage of control.crop.crop_stages; track stage.id) {
                <div class="stage-card">
                  <h3 class="stage-card__title">{{ stage.name }}</h3>
                  <div class="stage-details">
                    @if (stage.thermal_requirement) {
                      <p><strong>{{ 'crops.show.required_gdd' | translate }}:</strong> {{ stage.thermal_requirement.required_gdd }} GDD</p>
                    }
                    @if (stage.temperature_requirement) {
                      <p><strong>{{ 'crops.show.optimal_temperature' | translate }}:</strong>
                        {{ stage.temperature_requirement.optimal_min }}°C - {{ stage.temperature_requirement.optimal_max }}°C</p>
                    }
                  </div>
                </div>
              }
            </div>
          </section>
        }
      }
    </main>
  `,
  styleUrl: './crop-detail.component.css'
})
export class CropDetailComponent implements CropDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadCropDetailUseCase);
  private readonly deleteUseCase = inject(DeleteCropUseCase);
  private readonly presenter = inject(CropDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropDetailViewState = initialControl;
  get control(): CropDetailViewState {
    return this._control;
  }
  set control(value: CropDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (!cropId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid crop id.' };
      return;
    }
    this.load(cropId);
  }

  load(cropId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ cropId });
  }

  reload(): void {
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (cropId) this.load(cropId);
  }

  deleteCrop(): void {
    if (!this.control.crop) return;
    this.deleteUseCase.execute({
      cropId: this.control.crop.id,
      onSuccess: () => this.router.navigate(['/crops'])
    });
  }
}
