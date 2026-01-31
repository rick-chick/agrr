import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';
import { PlanNewView, PlanNewViewState } from './plan-new.view';
import { LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT } from '../../usecase/private-plan-create/load-private-plan-farms.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';

const initialControl: PlanNewViewState = {
  loading: true,
  error: null,
  farms: []
};

@Component({
  selector: 'app-plan-new',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PlanNewPresenter,
    LoadPrivatePlanFarmsUseCase,
    { provide: LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT, useExisting: PlanNewPresenter },
    { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">新規計画</h1>
        <p class="page-description">農場を選択して新しい計画を作成します。</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="plan-new-error">{{ control.error }}</p>
        } @else {
          <form class="form" (ngSubmit)="onFarmSelect($event)">
            <div class="form-group">
              <label for="farm-select" class="form-label">農場を選択</label>
              <select id="farm-select" name="farmId" class="form-control" required>
                <option value="">農場を選択してください</option>
                @for (farm of control.farms; track farm.id) {
                  <option [value]="farm.id">{{ farm.name }}</option>
                }
              </select>
            </div>
            <div class="form-actions">
              <a routerLink="/plans" class="btn-secondary">キャンセル</a>
              <button type="submit" class="btn-primary">次へ</button>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './plan-new.component.css'
})
export class PlanNewComponent implements PlanNewView, OnInit {
  private readonly useCase = inject(LoadPrivatePlanFarmsUseCase);
  private readonly presenter = inject(PlanNewPresenter);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanNewViewState = initialControl;
  get control(): PlanNewViewState {
    return this._control;
  }
  set control(value: PlanNewViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute();
  }

  onFarmSelect(event: Event): void {
    event.preventDefault();
    const form = event.target as HTMLFormElement;
    const select = form.querySelector('select[name="farmId"]') as HTMLSelectElement;
    const farmId = select?.value;

    if (farmId) {
      this.router.navigate(['/plans/select-crop'], { queryParams: { farmId } });
    }
  }
}