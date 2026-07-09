import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { FertilizeDetailView, FertilizeDetailViewState } from './fertilize-detail.view';
import { LoadFertilizeDetailUseCase } from '../../../usecase/fertilizes/load-fertilize-detail.usecase';
import {
  FertilizeDetailPresenter,
  FERTILIZE_DETAIL_PROVIDERS
} from '../../../usecase/fertilizes/fertilize-detail.providers';

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialControl: FertilizeDetailViewState = {
  loading: true,
  error: null,
  fertilize: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-fertilize-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, MasterContextHeaderComponent],
  providers: [...FERTILIZE_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.fertilize) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.fertilize.name }}</h1>
          <dl class="detail-card__list">
            @if (control.fertilize.n !== null && control.fertilize.n !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.show.n' | translate }}</dt>
                <dd class="detail-row__value">{{ control.fertilize.n }}</dd>
              </div>
            }
            @if (control.fertilize.p !== null && control.fertilize.p !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.show.p' | translate }}</dt>
                <dd class="detail-row__value">{{ control.fertilize.p }}</dd>
              </div>
            }
            @if (control.fertilize.k !== null && control.fertilize.k !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.show.k' | translate }}</dt>
                <dd class="detail-row__value">{{ control.fertilize.k }}</dd>
              </div>
            }
            @if (control.fertilize.description) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.show.description' | translate }}</dt>
                <dd class="detail-row__value">{{ control.fertilize.description }}</dd>
              </div>
            }
            @if (control.fertilize.package_size !== null && control.fertilize.package_size !== undefined) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.show.package_size' | translate }}</dt>
                <dd class="detail-row__value">{{ control.fertilize.package_size }}</dd>
              </div>
            }
            @if (control.fertilize.region) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'fertilizes.form.region_label' | translate }}</dt>
                <dd class="detail-row__value">{{ 'fertilizes.form.region_' + control.fertilize.region | translate }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/fertilizes', control.fertilize.id, 'edit']" class="btn-primary">
              {{ 'fertilizes.show.edit' | translate }}
            </a>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./fertilize-detail.component.css']
})
export class FertilizeDetailComponent implements FertilizeDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadFertilizeDetailUseCase);
  private readonly presenter = inject(FertilizeDetailPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'fertilizes.index.title', routerLink: ['/fertilizes'] }
    ];
    if (this.control.fertilize) {
      crumbs.push({ label: this.control.fertilize.name });
    }
    return crumbs;
  }

  private _control: FertilizeDetailViewState = initialControl;
  get control(): FertilizeDetailViewState {
    return this._control;
  }
  set control(value: FertilizeDetailViewState) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
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
