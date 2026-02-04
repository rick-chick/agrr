import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { provideRouter } from '@angular/router';
import { vi } from 'vitest';
import { PlanListComponent } from './plan-list.component';
import { LoadPlanListUseCase } from '../../usecase/plans/load-plan-list.usecase';
import { DeletePlanUseCase } from '../../usecase/plans/delete-plan.usecase';
import { PlanListPresenter } from '../../adapters/plans/plan-list.presenter';
import { LOAD_PLAN_LIST_OUTPUT_PORT } from '../../usecase/plans/load-plan-list.output-port';
import { DELETE_PLAN_OUTPUT_PORT } from '../../usecase/plans/delete-plan.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanListViewState } from './plan-list.view';
import { PlanSummary } from '../../domain/plans/plan-summary';

describe('PlanListComponent', () => {
  let component: PlanListComponent;
  let fixture: ComponentFixture<PlanListComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  const renderPlans = async (plans: PlanSummary[]) => {
    const loadSpy = vi.spyOn(component, 'load').mockImplementation(() => {});
    try {
      component.control = {
        loading: false,
        error: null,
        plans
      };
      fixture.detectChanges();
      await fixture.whenStable();
      return fixture.nativeElement;
    } finally {
      loadSpy.mockRestore();
    }
  };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    deleteUseCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [PlanListComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(PlanListComponent, {
        set: {
          providers: [
            { provide: LoadPlanListUseCase, useValue: loadUseCase },
            { provide: DeletePlanUseCase, useValue: deleteUseCase },
            { provide: PlanListPresenter, useValue: presenter },
            { provide: LOAD_PLAN_LIST_OUTPUT_PORT, useValue: presenter },
            { provide: DELETE_PLAN_OUTPUT_PORT, useValue: presenter },
            { provide: PLAN_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(PlanListComponent);
    component = fixture.componentInstance;

    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: PlanListViewState = {
      loading: false,
      error: null,
      plans: []
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: PlanListViewState = {
      loading: false,
      error: null,
      plans: []
    };
    component.control = state;
    expect(cdr.markForCheck).toHaveBeenCalled();
  });

  it('calls useCase.execute on load', () => {
    component.load();
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('refreshAfterUndo triggers loadUseCase', () => {
    component.refreshAfterUndo();
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('deletePlan calls deleteUseCase with onAfterUndo callback', () => {
    const planId = 12;

    component.deletePlan(planId);

    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      planId,
      onAfterUndo: expect.any(Function)
    });
  });

  it('onAfterUndo callback triggers refreshAfterUndo', () => {
    component.deletePlan(42);

    const executeCall = deleteUseCase.execute.mock.calls[0][0];
    expect(executeCall.onAfterUndo).toBeDefined();

    executeCall.onAfterUndo!();

    expect(loadUseCase.execute).toHaveBeenCalledTimes(1);
  });

  it('ngOnInit sets view on presenter and calls load', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('displays plans in the list', async () => {
    const plans: PlanSummary[] = [
      { id: 1, name: 'Plan A', status: 'pending' },
      { id: 2, name: 'Plan B', status: 'completed' }
    ];

    const planTitles = (await renderPlans(plans)).querySelectorAll('.item-card__title');
    expect(planTitles).toHaveLength(2);
    expect(planTitles[0].textContent.trim()).toBe('Plan A');
    expect(planTitles[1].textContent.trim()).toBe('Plan B');
  });

  it('delete button triggers deletePlan action', async () => {
    const plans: PlanSummary[] = [
      { id: 1, name: 'Plan A', status: 'pending' }
    ];

    const nativeElement = await renderPlans(plans);
    const deleteSpy = vi.spyOn(component, 'deletePlan');

    const deleteButton = nativeElement.querySelector('.item-card__actions .btn-danger');
    deleteButton.click();

    expect(deleteSpy).toHaveBeenCalledWith(1);
  });
});
