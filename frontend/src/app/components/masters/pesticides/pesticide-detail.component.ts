import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PesticideDetailView, PesticideDetailViewState } from './pesticide-detail.view';
import { LoadPesticideDetailUseCase } from '../../../usecase/pesticides/load-pesticide-detail.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import { PesticideDetailPresenter } from '../../../adapters/pesticides/pesticide-detail.presenter';
import { LOAD_PESTICIDE_DETAIL_OUTPUT_PORT } from '../../../usecase/pesticides/load-pesticide-detail.output-port';
import { DELETE_PESTICIDE_OUTPUT_PORT } from '../../../usecase/pesticides/delete-pesticide.output-port';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { PesticideApiGateway } from '../../../adapters/pesticides/pesticide-api.gateway';
import { Crop } from '../../../domain/crops/crop';
import { Pest } from '../../../domain/pests/pest';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialControl: PesticideDetailViewState = {
  loading: true,
  error: null,
  pesticide: null
};

@Component({
  selector: 'app-pesticide-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    PesticideDetailPresenter,
    LoadPesticideDetailUseCase,
    DeletePesticideUseCase,
    { provide: LOAD_PESTICIDE_DETAIL_OUTPUT_PORT, useExisting: PesticideDetailPresenter },
    { provide: DELETE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideDetailPresenter },
    { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
    { provide: CROP_GATEWAY, useClass: CropApiGateway },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">Loading...</p>
      } @else if (control.error) {
        <p class="master-error">{{ control.error }}</p>
      } @else if (control.pesticide) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.pesticide.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">Name</dt>
              <dd class="detail-row__value">{{ control.pesticide.name }}</dd>
            </div>
            @if (control.pesticide.active_ingredient) {
              <div class="detail-row">
                <dt class="detail-row__term">Active Ingredient</dt>
                <dd class="detail-row__value">{{ control.pesticide.active_ingredient }}</dd>
              </div>
            }
            @if (control.pesticide.description) {
              <div class="detail-row">
                <dt class="detail-row__term">Description</dt>
                <dd class="detail-row__value">{{ control.pesticide.description }}</dd>
              </div>
            }
            <div class="detail-row">
              <dt class="detail-row__term">Crop</dt>
              <dd class="detail-row__value">{{ getCropName(control.pesticide.crop_id) }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">Pest</dt>
              <dd class="detail-row__value">{{ getPestName(control.pesticide.pest_id) }}</dd>
            </div>
            @if (control.pesticide.region) {
              <div class="detail-row">
                <dt class="detail-row__term">Region</dt>
                <dd class="detail-row__value">{{ control.pesticide.region }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/pesticides']" class="btn-secondary">Back</a>
            <a [routerLink]="['/pesticides', control.pesticide.id, 'edit']" class="btn-secondary">Edit</a>
            <button type="button" class="btn-danger" (click)="deletePesticide()">Delete</button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrl: './pesticide-detail.component.css'
})
export class PesticideDetailComponent implements PesticideDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPesticideDetailUseCase);
  private readonly deleteUseCase = inject(DeletePesticideUseCase);
  private readonly presenter = inject(PesticideDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly cropGateway = inject(CROP_GATEWAY);
  private readonly pestGateway = inject(PEST_GATEWAY);

  crops: Crop[] = [];
  pests: Pest[] = [];

  private _control: PesticideDetailViewState = initialControl;
  get control(): PesticideDetailViewState {
    return this._control;
  }
  set control(value: PesticideDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadCropsAndPests();
    const pesticideId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pesticideId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid pesticide id.' };
      return;
    }
    this.load(pesticideId);
  }

  private loadCropsAndPests(): void {
    this.cropGateway.list().subscribe(crops => this.crops = crops);
    this.pestGateway.list().subscribe(pests => this.pests = pests);
  }

  getCropName(cropId: number): string {
    const crop = this.crops.find(c => c.id === cropId);
    return crop ? crop.name : `Crop ${cropId}`;
  }

  getPestName(pestId: number): string {
    const pest = this.pests.find(p => p.id === pestId);
    return pest ? pest.name : `Pest ${pestId}`;
  }

  load(pesticideId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ pesticideId });
  }

  deletePesticide(): void {
    if (!this.control.pesticide) return;
    this.deleteUseCase.execute({
      pesticideId: this.control.pesticide.id,
      onSuccess: () => this.router.navigate(['/pesticides'])
    });
  }
}