import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FertilizeDetailView, FertilizeDetailViewState } from './fertilize-detail.view';
import { LoadFertilizeDetailUseCase } from '../../../usecase/fertilizes/load-fertilize-detail.usecase';
import { FertilizeDetailPresenter } from '../../../adapters/fertilizes/fertilize-detail.presenter';
import { LOAD_FERTILIZE_DETAIL_OUTPUT_PORT } from '../../../usecase/fertilizes/load-fertilize-detail.output-port';
import { FERTILIZE_GATEWAY } from '../../../usecase/fertilizes/fertilize-gateway';
import { FertilizeApiGateway } from '../../../adapters/fertilizes/fertilize-api.gateway';

const initialControl: FertilizeDetailViewState = {
  loading: true,
  error: null,
  fertilize: null
};

@Component({
  selector: 'app-fertilize-detail',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    FertilizeDetailPresenter,
    LoadFertilizeDetailUseCase,
    { provide: LOAD_FERTILIZE_DETAIL_OUTPUT_PORT, useExisting: FertilizeDetailPresenter },
    { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">Loading...</p>
      } @else if (control.fertilize) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.fertilize.name }}</h1>
          <dl class="detail-card__list">
            @if (control.fertilize.n !== null && control.fertilize.n !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">N</dt>
                <dd class="detail-row__value">{{ control.fertilize.n }}</dd>
              </div>
            }
            @if (control.fertilize.p !== null && control.fertilize.p !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">P</dt>
                <dd class="detail-row__value">{{ control.fertilize.p }}</dd>
              </div>
            }
            @if (control.fertilize.k !== null && control.fertilize.k !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">K</dt>
                <dd class="detail-row__value">{{ control.fertilize.k }}</dd>
              </div>
            }
            @if (control.fertilize.description) {
              <div class="detail-row">
                <dt class="detail-row__term">Description</dt>
                <dd class="detail-row__value">{{ control.fertilize.description }}</dd>
              </div>
            }
            @if (control.fertilize.package_size !== null && control.fertilize.package_size !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">Package Size</dt>
                <dd class="detail-row__value">{{ control.fertilize.package_size }}</dd>
              </div>
            }
            @if (control.fertilize.region) {
              <div class="detail-row">
                <dt class="detail-row__term">Region</dt>
                <dd class="detail-row__value">{{ control.fertilize.region }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/fertilizes', control.fertilize.id, 'edit']" class="btn-primary">Edit</a>
            <a [routerLink]="['/fertilizes']" class="btn-secondary">Back to fertilizes</a>
          </div>
        </section>
      }
    </main>
  `,
  styleUrl: './fertilize-detail.component.css'
})
export class FertilizeDetailComponent implements FertilizeDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadFertilizeDetailUseCase);
  private readonly presenter = inject(FertilizeDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeDetailViewState = initialControl;
  get control(): FertilizeDetailViewState {
    return this._control;
  }
  set control(value: FertilizeDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const fertilizeId = Number(this.route.snapshot.paramMap.get('id'));
    if (!fertilizeId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid fertilize id.' };
      return;
    }
    this.load(fertilizeId);
  }

  load(fertilizeId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ fertilizeId });
  }
}
