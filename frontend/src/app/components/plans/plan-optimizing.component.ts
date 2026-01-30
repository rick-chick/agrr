import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Channel } from 'actioncable';
import { PlanOptimizingView, PlanOptimizingViewState } from './plan-optimizing.view';
import { SubscribePlanOptimizationUseCase } from '../../usecase/plans/subscribe-plan-optimization.usecase';
import { PlanOptimizingPresenter } from '../../adapters/plans/plan-optimizing.presenter';
import { SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT } from '../../usecase/plans/subscribe-plan-optimization.output-port';
import { PLAN_OPTIMIZATION_GATEWAY } from '../../usecase/plans/plan-optimization-gateway';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';

const initialControl: PlanOptimizingViewState = {
  status: 'pending',
  progress: 0
};

@Component({
  selector: 'app-plan-optimizing',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PlanOptimizingPresenter,
    SubscribePlanOptimizationUseCase,
    { provide: SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT, useExisting: PlanOptimizingPresenter },
    { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway }
  ],
  template: `
    <section class="page">
      <a [routerLink]="['/plans', planId]">Back to plan</a>
      <h2>Optimizing</h2>
      <p>Status: {{ control.status }}</p>
      <p>Progress: {{ control.progress }}%</p>
    </section>
  `,
  styleUrl: './plan-optimizing.component.css'
})
export class PlanOptimizingComponent implements PlanOptimizingView, OnDestroy, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(SubscribePlanOptimizationUseCase);
  private readonly presenter = inject(PlanOptimizingPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private channel: Channel | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanOptimizingViewState = initialControl;
  get control(): PlanOptimizingViewState {
    return this._control;
  }
  set control(value: PlanOptimizingViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = this.planId;
    if (!planId) {
      this.control = { status: 'invalid_plan_id', progress: 0 };
      return;
    }
    this.useCase.execute({
      planId,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
  }
}
