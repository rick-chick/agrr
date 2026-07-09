import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PesticideDetailView, PesticideDetailViewState } from './pesticide-detail.view';
import { LoadPesticideDetailUseCase } from '../../../usecase/pesticides/load-pesticide-detail.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import {
  PesticideDetailPresenter,
  PESTICIDE_DETAIL_PROVIDERS
} from '../../../usecase/pesticides/pesticide-detail.providers';
import { Pesticide } from '../../../domain/pesticides/pesticide';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialControl: PesticideDetailViewState = {
  loading: true,
  error: null,
  pesticide: null,
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-pesticide-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, MasterContextHeaderComponent],
  providers: [...PESTICIDE_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.pesticide) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.pesticide.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'pesticides.show.name' | translate }}</dt>
              <dd class="detail-row__value">{{ control.pesticide.name }}</dd>
            </div>
            @if (control.pesticide.active_ingredient) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'pesticides.show.active_ingredient' | translate }}</dt>
                <dd class="detail-row__value">{{ control.pesticide.active_ingredient }}</dd>
              </div>
            }
            @if (control.pesticide.description) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'pesticides.show.description' | translate }}</dt>
                <dd class="detail-row__value">{{ control.pesticide.description }}</dd>
              </div>
            }
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'pesticides.show.crop' | translate }}</dt>
              <dd class="detail-row__value">{{ getCropName(control.pesticide) }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'pesticides.show.pest' | translate }}</dt>
              <dd class="detail-row__value">{{ getPestName(control.pesticide) }}</dd>
            </div>
            @if (control.pesticide.region) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'pesticides.form.region_label' | translate }}</dt>
                <dd class="detail-row__value">{{ control.pesticide.region }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/pesticides', control.pesticide.id, 'edit']" class="btn-primary">{{ 'pesticides.show.edit' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deletePesticide()">{{ 'pesticides.show.delete' | translate }}</button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./pesticide-detail.component.css']
})
export class PesticideDetailComponent implements PesticideDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly useCase = inject(LoadPesticideDetailUseCase);
  private readonly deleteUseCase = inject(DeletePesticideUseCase);
  private readonly presenter = inject(PesticideDetailPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'pesticides.index.title', routerLink: ['/pesticides'] }
    ];
    if (this.control.pesticide) {
      crumbs.push({ label: this.control.pesticide.name });
    }
    return crumbs;
  }

  private _control: PesticideDetailViewState = initialControl;
  get control(): PesticideDetailViewState {
    return this._control;
  }
  set control(value: PesticideDetailViewState) {
    const next = applyPendingUndoToastViewEffects(
      applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage }),
      { toast: this.undoToast }
    );
    this._control = next;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const pesticideId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pesticideId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('pesticides.errors.invalid_id')
      };
      return;
    }
    this.load(pesticideId);
  }

  getCropName(pesticide: Pesticide): string {
    if (pesticide.crop_name) return pesticide.crop_name;
    return this.translate.instant('pesticides.fallback.crop', { id: pesticide.crop_id });
  }

  getPestName(pesticide: Pesticide): string {
    if (pesticide.pest_name) return pesticide.pest_name;
    return this.translate.instant('pesticides.fallback.pest', { id: pesticide.pest_id });
  }

  load(pesticideId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ pesticideId });
  }

  reload(): void {
    const pesticideId = Number(this.route.snapshot.paramMap.get('id'));
    if (pesticideId) this.load(pesticideId);
  }

  deletePesticide(): void {
    if (!this.control.pesticide) return;
    this.deleteUseCase.execute({
      pesticideId: this.control.pesticide.id,
      onSuccess: () => this.router.navigate(['/pesticides'])
    });
  }
}