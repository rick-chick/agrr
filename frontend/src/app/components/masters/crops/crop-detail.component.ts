import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropDetailView, CropDetailViewState } from './crop-detail.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { CropDetailPresenter } from '../../../adapters/crops/crop-detail.presenter';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from '../../../usecase/crops/load-crop-detail.output-port';
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
    { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropDetailPresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <div class="content-card">
      <div class="page-header">
        <a [routerLink]="['/crops']" class="btn btn-white">{{ 'common.back' | translate }}</a>
      </div>

      @if (control.loading) {
        <p>{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.crop) {
        <h2 class="page-title">{{ control.crop.name }}</h2>
        <section class="info-section">
          <h3>{{ 'crops.show.name' | translate }}</h3>
          <p>{{ control.crop.name }}</p>
          <h3 *ngIf="control.crop.variety">{{ 'crops.show.variety' | translate }}</h3>
          <p *ngIf="control.crop.variety">{{ control.crop.variety }}</p>
        </section>

        <section class="stages-section" *ngIf="control.crop.crop_stages?.length">
          <h3>{{ 'crops.show.stages_title' | translate }}</h3>
          <div class="stages-grid">
            @for (stage of control.crop.crop_stages; track stage.id) {
              <div class="stage-card">
                <h4>{{ stage.name }}</h4>
                <div class="stage-details">
                  <div *ngIf="stage.thermal_requirement">
                    <strong>{{ 'crops.show.required_gdd' | translate }}:</strong> {{ stage.thermal_requirement.required_gdd }} GDD
                  </div>
                  <div *ngIf="stage.temperature_requirement">
                    <strong>{{ 'crops.show.optimal_temperature' | translate }}:</strong>
                    {{ stage.temperature_requirement.optimal_min }}°C - {{ stage.temperature_requirement.optimal_max }}°C
                  </div>
                </div>
              </div>
            }
          </div>
        </section>
      }
    </div>
  `,
  styles: [`
    .stages-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
      gap: 1rem;
      margin-top: 1rem;
    }
    .stage-card {
      border: 1px solid var(--color-gray-200);
      padding: 1rem;
      border-radius: var(--radius-md);
      background: var(--color-gray-50);
    }
    .stage-card h4 {
      margin-top: 0;
      color: var(--color-primary);
    }
    .info-section {
      margin-bottom: 2rem;
    }
  `]
})
export class CropDetailComponent implements CropDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadCropDetailUseCase);
  private readonly presenter = inject(CropDetailPresenter);

  private _control: CropDetailViewState = initialControl;
  get control(): CropDetailViewState {
    return this._control;
  }
  set control(value: CropDetailViewState) {
    this._control = value;
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
}
