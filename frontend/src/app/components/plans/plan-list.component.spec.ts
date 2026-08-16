import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { provideRouter } from '@angular/router';
import { vi } from 'vitest';
import { PlanListComponent } from './plan-list.component';
import { LoadPlanListUseCase } from '../../usecase/plans/load-plan-list.usecase';
import { DeletePlanUseCase } from '../../usecase/plans/delete-plan.usecase';
import { PlanListPresenter } from '../../usecase/plans/plan-list.providers';
import { LOAD_PLAN_LIST_OUTPUT_PORT } from '../../usecase/plans/load-plan-list.output-port';
import { DELETE_PLAN_OUTPUT_PORT } from '../../usecase/plans/delete-plan.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanListViewState } from './plan-list.view';
import { PlanListPlan } from '../../domain/plans/plan-list-plan';

describe('PlanListComponent', () => {
  let component: PlanListComponent;
  let fixture: ComponentFixture<PlanListComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  const renderPlans = async (plans: PlanListPlan[]) => {
    const loadSpy = vi.spyOn(component, 'load').mockImplementation(() => {});
    try {
      component.control = {
        loading: false,
        error: null,
        plans,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      fixture.detectChanges();
      await fixture.whenStable();
      return fixture.nativeElement;
    } finally {
      loadSpy.mockRestore();
    }
  };

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

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

    const translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('en', {
      plans: {
        index: {
          delete_confirm_message:
            'Delete this cultivation plan? Field assignments and work record links will be removed. You can undo shortly after deleting.',
          input_gap: {
            unrecorded_summary: 'Unrecorded: {{count}}',
            action_required_summary: 'Action required: {{count}}',
            amount_variance_summary: 'Amount variance: {{count}}',
            work_link: 'Record work',
            learn_link: 'Review learning'
          },
          farm_group: {
            expand: 'Expand',
            collapse: 'Collapse',
            compare_variance: 'Compare variance'
          },
          year_label: 'Year {{year}}',
          status: {
            pending: 'Pending',
            completed: 'Completed'
          }
        }
      },
      common: { cancel: 'Cancel', delete: 'Delete', show: 'Show' }
    });
    translateService.use('en');

    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  const planWithGap = (
    overrides: Partial<PlanListPlan> = {}
  ): PlanListPlan => ({
    id: 1,
    name: 'Plan A',
    status: 'pending',
    farm_id: 1,
    farm_name: 'Farm A',
    plan_year: 2026,
    inputGap: { unrecordedCount: 0, actionRequiredCount: 0, structuredUnrecordedCount: 0, amountVarianceCount: 0 },
    ...overrides
  });

  it('implements View control getter/setter', () => {
    const state: PlanListViewState = {
      loading: false,
      error: null,
      plans: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('uses div.page-main instead of nested main landmark', async () => {
    await renderPlans([]);
    expect(fixture.nativeElement.querySelector('main')).toBeNull();
    const pageMain = fixture.nativeElement.querySelector('.page-main');
    expect(pageMain).toBeTruthy();
    expect(pageMain?.tagName).toBe('DIV');
  });

  it('calls markForCheck when control is updated', () => {
    const state: PlanListViewState = {
      loading: false,
      error: null,
      plans: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
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

  it('deletePlan opens confirm dialog before calling deleteUseCase', async () => {
    await renderPlans([planWithGap({ id: 12, name: 'Plan A' })]);
    component.deleteConfirmDialogRef = {
      nativeElement: { showModal: vi.fn(), close: vi.fn() }
    } as never;

    component.deletePlan(12);

    expect(component.deleteConfirmDialogRef?.nativeElement.showModal).toHaveBeenCalled();
    expect(deleteUseCase.execute).not.toHaveBeenCalled();

    component.confirmDeletePlan();
    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      planId: 12,
      onAfterUndo: expect.any(Function)
    });
  });

  it('onAfterUndo callback triggers refreshAfterUndo', () => {
    component.deleteConfirmDialogRef = {
      nativeElement: { showModal: vi.fn(), close: vi.fn() }
    } as never;
    component.deletePlan(42);
    component.confirmDeletePlan();

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

  it('uses standard page-header without inline create CTA', async () => {
    const loadSpy = vi.spyOn(component, 'load').mockImplementation(() => {});
    try {
      component.control = {
        loading: false,
        error: null,
        plans: [planWithGap()],
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      fixture.detectChanges();
      await fixture.whenStable();
      const header = fixture.nativeElement.querySelector('.page-header');
      expect(header).toBeTruthy();
      expect(header.classList.contains('page-header--with-action')).toBe(false);
      expect(header.querySelector('.btn-primary')).toBeNull();
    } finally {
      loadSpy.mockRestore();
    }
  });

  it('shows create plan link in section-card header actions when plans exist', async () => {
    const nativeElement = await renderPlans([planWithGap()]);
    const link = nativeElement.querySelector('.section-card__header-actions .btn-primary');
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/new');
  });

  it('shows detail and delete actions on plan cards', async () => {
    const nativeElement = await renderPlans([planWithGap()]);
    const showLink = nativeElement.querySelector('.item-card__actions a[href*="/plans/1"]:not([href*="/work"]):not([href*="/learn"])');
    const danger = nativeElement.querySelector('.item-card__actions .btn-danger');
    expect(showLink).toBeTruthy();
    expect(showLink.getAttribute('href')).toContain('/plans/1');
    expect(danger).toBeTruthy();
  });

  it('shows empty state with create CTA when no plans', async () => {
    const nativeElement = await renderPlans([]);
    expect(nativeElement.querySelector('.plan-list-empty')).toBeTruthy();
    expect(nativeElement.querySelector('.plan-list-empty .btn-primary')).toBeTruthy();
  });

  it('shows initial setup link in empty state', async () => {
    const nativeElement = await renderPlans([]);
    const setupLink = nativeElement.querySelector(
      '.plan-list-empty-setup'
    ) as HTMLAnchorElement;
    expect(setupLink).toBeTruthy();
    expect(setupLink.getAttribute('href')).toBe('/onboarding');
  });

  it('displays plans in the list', async () => {
    const plans: PlanListPlan[] = [
      planWithGap({ id: 1, name: 'Plan A' }),
      planWithGap({ id: 2, name: 'Plan B', status: 'completed', farm_id: 2, farm_name: 'Farm B' })
    ];

    const planTitles = (await renderPlans(plans)).querySelectorAll('.item-card__title');
    expect(planTitles).toHaveLength(2);
    expect(planTitles[0].textContent.trim()).toBe('Plan A');
    expect(planTitles[1].textContent.trim()).toBe('Plan B');
  });

  it('groups plans by farm with collapsible sections', async () => {
    const nativeElement = await renderPlans([
      planWithGap({ id: 1, farm_id: 1, farm_name: 'Farm A' }),
      planWithGap({ id: 2, farm_id: 2, farm_name: 'Farm B', name: 'Plan B' })
    ]);

    const groups = nativeElement.querySelectorAll('.plan-list__farm-group');
    expect(groups).toHaveLength(2);
    expect(nativeElement.querySelector('#plan-list-farm-1')?.textContent).toContain('Farm A');
    expect(nativeElement.querySelector('#plan-list-farm-2')?.textContent).toContain('Farm B');

    component.toggleFarmGroup(1);
    fixture.detectChanges();

    expect(nativeElement.querySelector('#plan-list-farm-plans-1')).toBeNull();
    expect(nativeElement.querySelector('#plan-list-farm-plans-2')).toBeTruthy();
  });

  it('shows plan_year and status on each plan card', async () => {
    const nativeElement = await renderPlans([
      planWithGap({ id: 1, plan_year: 2025, status: 'pending' })
    ]);

    expect(nativeElement.querySelector('.plan-list__plan-year')?.textContent).toContain('2025');
    expect(nativeElement.querySelector('.plan-list__plan-status')?.textContent).toContain('Pending');
  });

  it('links compare variance to /work/variance with farm filter', async () => {
    const nativeElement = await renderPlans([planWithGap({ farm_id: 42, farm_name: 'Farm A' })]);

    const link = nativeElement.querySelector('.plan-list__variance-link') as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/work/variance');
    expect(link.getAttribute('href')).toContain('farm_id=42');
  });

  it('delete button opens delete confirm dialog', async () => {
    const nativeElement = await renderPlans([planWithGap()]);
    component.deleteConfirmDialogRef = {
      nativeElement: { showModal: vi.fn(), close: vi.fn() }
    } as never;
    const deleteSpy = vi.spyOn(component, 'deletePlan');

    const deleteButton = nativeElement.querySelector('.item-card__actions .btn-danger');
    deleteButton.click();

    expect(deleteSpy).toHaveBeenCalledWith(1);
    expect(component.deleteConfirmDialogRef?.nativeElement.showModal).toHaveBeenCalled();
  });

  it('delete button uses outline danger style (not filled red background)', async () => {
    const nativeElement = await renderPlans([planWithGap()]);
    const deleteButton = nativeElement.querySelector(
      '.item-card__actions .btn-danger'
    ) as HTMLElement;
    expect(deleteButton).toBeTruthy();

    const styles = getComputedStyle(deleteButton);
    expect(styles.color).not.toBe('var(--color-text-on-primary)');
    expect(styles.color).toBe('var(--color-error)');
    expect(styles.borderStyle).not.toBe('none');
  });

  it('shows amount variance in input gap summary when count is positive', async () => {
    const nativeElement = await renderPlans([
      planWithGap({
        inputGap: {
          unrecordedCount: 0,
          actionRequiredCount: 0,
          structuredUnrecordedCount: 0,
          amountVarianceCount: 4
        }
      })
    ]);

    const gapSummary = nativeElement.querySelector('.plan-list__gap-summary');
    expect(gapSummary?.textContent).toContain('Amount variance: 4');
  });

  it('shows input gap summary and work/learn links on plan cards', async () => {
    const nativeElement = await renderPlans([
      planWithGap({
        inputGap: { unrecordedCount: 3, actionRequiredCount: 2, structuredUnrecordedCount: 0, amountVarianceCount: 0 }
      })
    ]);

    const gapSummary = nativeElement.querySelector('.plan-list__gap-summary');
    expect(gapSummary?.textContent).toContain('Unrecorded: 3');
    expect(gapSummary?.textContent).toContain('Action required: 2');

    const workLink = nativeElement.querySelector('.plan-list__work-link');
    const learnLink = nativeElement.querySelector('.plan-list__learn-link');
    expect(workLink).toBeTruthy();
    expect(workLink.getAttribute('href')).toContain('/plans/1/work');
    expect(learnLink).toBeTruthy();
    expect(learnLink.getAttribute('href')).toContain('/plans/1/learn');
  });

  it('hides input gap summary when inputGap is null', async () => {
    const nativeElement = await renderPlans([planWithGap({ inputGap: null })]);

    expect(nativeElement.querySelector('.plan-list__gap-summary')).toBeNull();
  });

  it('shows card-list skeleton while loading instead of text-only spinner', async () => {
    const loadSpy = vi.spyOn(component, 'load').mockImplementation(() => {});
    try {
      component.control = {
        loading: true,
        error: null,
        plans: [],
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      fixture.detectChanges();
      await fixture.whenStable();

      expect(fixture.nativeElement.querySelector('app-card-list-skeleton')).toBeTruthy();
      expect(fixture.nativeElement.querySelector('.master-loading:not(.list-loading-text)')).toBeNull();
    } finally {
      loadSpy.mockRestore();
    }
  });

  it('shows error alert with retry button that reloads the plan list', async () => {
    const loadSpy = vi.spyOn(component, 'load').mockImplementation(() => {});
    try {
      component.control = {
        loading: false,
        error: 'common.api_error.generic',
        plans: [],
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      fixture.detectChanges();
      await fixture.whenStable();

      const alert = fixture.nativeElement.querySelector('.page-alert-error[role="alert"]');
      expect(alert).toBeTruthy();
      expect(alert.textContent).toContain('common.api_error.generic');
      expect(fixture.nativeElement.querySelector('app-card-list-skeleton')).toBeNull();

      const retryBtn = fixture.nativeElement.querySelector('.plan-list__retry');
      expect(retryBtn).toBeTruthy();

      loadSpy.mockRestore();
      loadUseCase.execute.mockClear();
      retryBtn.click();
      expect(loadUseCase.execute).toHaveBeenCalled();
    } finally {
      loadSpy.mockRestore();
    }
  });
});
