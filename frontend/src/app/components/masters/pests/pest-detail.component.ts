import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PestDetailView, PestDetailViewState } from './pest-detail.view';
import { LoadPestDetailUseCase } from '../../../usecase/pests/load-pest-detail.usecase';
import { DeletePestUseCase } from '../../../usecase/pests/delete-pest.usecase';
import { PestDetailPresenter } from '../../../adapters/pests/pest-detail.presenter';
import { LOAD_PEST_DETAIL_OUTPUT_PORT } from '../../../usecase/pests/load-pest-detail.output-port';
import { DELETE_PEST_OUTPUT_PORT } from '../../../usecase/pests/delete-pest.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialControl: PestDetailViewState = {
  loading: true,
  error: null,
  pest: null
};

@Component({
  selector: 'app-pest-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    PestDetailPresenter,
    LoadPestDetailUseCase,
    DeletePestUseCase,
    { provide: LOAD_PEST_DETAIL_OUTPUT_PORT, useExisting: PestDetailPresenter },
    { provide: DELETE_PEST_OUTPUT_PORT, useExisting: PestDetailPresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">Loading...</p>
      } @else if (control.pest) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.pest.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">Name</dt>
              <dd class="detail-row__value">{{ control.pest.name }}</dd>
            </div>
            @if (control.pest.name_scientific) {
              <div class="detail-row">
                <dt class="detail-row__term">Scientific Name</dt>
                <dd class="detail-row__value">{{ control.pest.name_scientific }}</dd>
              </div>
            }
            @if (control.pest.family) {
              <div class="detail-row">
                <dt class="detail-row__term">Family</dt>
                <dd class="detail-row__value">{{ control.pest.family }}</dd>
              </div>
            }
            @if (control.pest.order) {
              <div class="detail-row">
                <dt class="detail-row__term">Order</dt>
                <dd class="detail-row__value">{{ control.pest.order }}</dd>
              </div>
            }
            @if (control.pest.description) {
              <div class="detail-row">
                <dt class="detail-row__term">Description</dt>
                <dd class="detail-row__value">{{ control.pest.description }}</dd>
              </div>
            }
            @if (control.pest.occurrence_season) {
              <div class="detail-row">
                <dt class="detail-row__term">Occurrence Season</dt>
                <dd class="detail-row__value">{{ control.pest.occurrence_season }}</dd>
              </div>
            }
            @if (control.pest.region) {
              <div class="detail-row">
                <dt class="detail-row__term">Region</dt>
                <dd class="detail-row__value">{{ control.pest.region }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/pests', control.pest.id, 'edit']" class="btn-primary">Edit</a>
            <a [routerLink]="['/pests']" class="btn-secondary">Back</a>
            <button type="button" class="btn-danger" (click)="deletePest()">Delete</button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./pest-detail.component.css']
})
export class PestDetailComponent implements PestDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPestDetailUseCase);
  private readonly deleteUseCase = inject(DeletePestUseCase);
  private readonly presenter = inject(PestDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestDetailViewState = initialControl;
  get control(): PestDetailViewState {
    return this._control;
  }
  set control(value: PestDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pestId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid pest id.' };
      return;
    }
    this.load(pestId);
  }

  load(pestId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ pestId });
  }

  reload(): void {
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (pestId) this.load(pestId);
  }

  deletePest(): void {
    if (!this.control.pest) return;
    this.deleteUseCase.execute({
      pestId: this.control.pest.id,
      onSuccess: () => this.router.navigate(['/pests'])
    });
  }
}