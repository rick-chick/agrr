import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { LoadPrivatePlanSelectCropContextUseCase } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanSelectCropPresenter } from '../../adapters/plans/plan-select-crop.presenter';
import { PlanSelectCropView, PlanSelectCropViewState } from './plan-select-crop.view';
import { LoadPrivatePlanSelectCropContextInputDto } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.dtos';
import { CreatePrivatePlanInputDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.output-port';
import { CREATE_PRIVATE_PLAN_OUTPUT_PORT } from '../../usecase/private-plan-create/create-private-plan.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';

const initialControl: PlanSelectCropViewState = {
  loading: true,
  error: null,
  farm: null,
  totalArea: 0,
  crops: [],
  creating: false
};

@Component({
  selector: 'app-plan-select-crop',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PlanSelectCropPresenter,
    LoadPrivatePlanSelectCropContextUseCase,
    CreatePrivatePlanUseCase,
    { provide: LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT, useExisting: PlanSelectCropPresenter },
    { provide: CREATE_PRIVATE_PLAN_OUTPUT_PORT, useExisting: PlanSelectCropPresenter },
    { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">作物選択</h1>
        <p class="page-description">
          @if (control.farm) {
            {{ control.farm.name }} の計画を作成します。栽培する作物を選択してください。
          }
        </p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="plan-select-crop-error">{{ control.error }}</p>
        } @else if (control.farm) {
          <form class="form" (ngSubmit)="onCreatePlan($event)">
            <div class="form-group">
              <label class="form-label">農場情報</label>
              <div class="farm-info">
                <p><strong>農場名:</strong> {{ control.farm.name }}</p>
                <p><strong>総面積:</strong> {{ control.totalArea }} ㎡</p>
              </div>
            </div>

            <div class="form-group">
              <label for="plan-name" class="form-label">計画名（任意）</label>
              <input
                type="text"
                id="plan-name"
                name="planName"
                class="form-control"
                placeholder="農場名が使用されます"
              />
            </div>

            <div class="form-group">
              <label class="form-label">栽培作物を選択</label>
              <div class="crop-checkboxes">
                @for (crop of control.crops; track crop.id) {
                  <label class="checkbox-item">
                    <input type="checkbox" name="cropIds" [value]="crop.id" />
                    {{ crop.name }}
                  </label>
                }
              </div>
            </div>

            <div class="form-actions">
              <a routerLink="/plans/new" class="btn-secondary">戻る</a>
              <button type="submit" class="btn-primary" [disabled]="control.creating">
                @if (control.creating) {
                  作成中...
                } @else {
                  計画を作成
                }
              </button>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './plan-select-crop.component.css'
})
export class PlanSelectCropComponent implements PlanSelectCropView, OnInit {
  private readonly loadContextUseCase = inject(LoadPrivatePlanSelectCropContextUseCase);
  private readonly createUseCase = inject(CreatePrivatePlanUseCase);
  private readonly presenter = inject(PlanSelectCropPresenter);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanSelectCropViewState = initialControl;
  get control(): PlanSelectCropViewState {
    return this._control;
  }
  set control(value: PlanSelectCropViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const farmId = this.route.snapshot.queryParams['farmId'];
    if (farmId) {
      this.load(Number(farmId));
    } else {
      this.control = { ...this.control, loading: false, error: '農場IDが指定されていません' };
    }
  }

  load(farmId: number): void {
    this.control = { ...this.control, loading: true };
    const input: LoadPrivatePlanSelectCropContextInputDto = { farmId };
    this.loadContextUseCase.execute(input);
  }

  onCreatePlan(event: Event): void {
    event.preventDefault();
    const form = event.target as HTMLFormElement;
    const formData = new FormData(form);

    const planName = (formData.get('planName') as string)?.trim();
    const cropCheckboxes = form.querySelectorAll('input[name="cropIds"]:checked') as NodeListOf<HTMLInputElement>;
    const cropIds: number[] = Array.from(cropCheckboxes).map(cb => Number(cb.value));

    if (cropIds.length === 0) {
      this.control = { ...this.control, error: '少なくとも1つの作物を選択してください' };
      return;
    }

    const farmId = Number(this.route.snapshot.queryParams['farmId']);
    if (!farmId) {
      this.control = { ...this.control, error: '農場IDが不明です' };
      return;
    }

    this.control = { ...this.control, creating: true, error: null };

    const input: CreatePrivatePlanInputDto = {
      farmId,
      planName: planName || undefined,
      cropIds
    };

    this.createUseCase.execute(input);
  }

  onPlanCreated(planId: number): void {
    this.router.navigate(['/plans', planId, 'optimizing']);
  }

  onPlanCreateError(error: string): void {
    this.control = { ...this.control, creating: false, error };
  }
}