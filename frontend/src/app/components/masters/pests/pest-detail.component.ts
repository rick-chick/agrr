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
    <div class="content-card">
      <div class="page-header">
        <a [routerLink]="['/pests']" class="btn btn-white">Back</a>
        @if (control.pest) {
          <a [routerLink]="['/pests', control.pest.id, 'edit']" class="btn btn-white">Edit</a>
          <button type="button" class="btn btn-danger" (click)="deletePest()">Delete</button>
        }
      </div>

      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.pest) {
        <h2 class="page-title">{{ control.pest.name }}</h2>
        <section class="info-section">
          <h3>Name</h3>
          <p>{{ control.pest.name }}</p>
          @if (control.pest.name_scientific) {
            <h3>Scientific Name</h3>
            <p>{{ control.pest.name_scientific }}</p>
          }
          @if (control.pest.family) {
            <h3>Family</h3>
            <p>{{ control.pest.family }}</p>
          }
          @if (control.pest.order) {
            <h3>Order</h3>
            <p>{{ control.pest.order }}</p>
          }
          @if (control.pest.description) {
            <h3>Description</h3>
            <p>{{ control.pest.description }}</p>
          }
          @if (control.pest.occurrence_season) {
            <h3>Occurrence Season</h3>
            <p>{{ control.pest.occurrence_season }}</p>
          }
          @if (control.pest.region) {
            <h3>Region</h3>
            <p>{{ control.pest.region }}</p>
          }
        </section>
      }
    </div>
  `,
  styles: [`
    .info-section {
      margin-bottom: 2rem;
    }
  `]
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

  deletePest(): void {
    if (!this.control.pest) return;
    this.deleteUseCase.execute({
      pestId: this.control.pest.id,
      onSuccess: () => this.router.navigate(['/pests'])
    });
  }
}