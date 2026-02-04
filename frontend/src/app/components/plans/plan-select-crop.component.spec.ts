import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { Router, ActivatedRoute } from '@angular/router';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanSelectCropComponent } from './plan-select-crop.component';
import { LoadPrivatePlanSelectCropContextUseCase } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanSelectCropPresenter } from '../../adapters/plans/plan-select-crop.presenter';

describe('PlanSelectCropComponent', () => {
  let component: PlanSelectCropComponent;
  let fixture: ComponentFixture<PlanSelectCropComponent>;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockCreateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockRouter: { navigate: ReturnType<typeof vi.fn> };
  let mockRoute: { snapshot: { queryParams: Record<string, string> } };

  beforeEach(async () => {
    mockLoadUseCase = { execute: vi.fn() };
    mockCreateUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockRouter = { navigate: vi.fn() };
    mockRoute = { snapshot: { queryParams: { farmId: '1' } } };

    await TestBed.configureTestingModule({
      imports: [PlanSelectCropComponent, TranslateModule.forRoot()],
      providers: [
        { provide: LoadPrivatePlanSelectCropContextUseCase, useValue: mockLoadUseCase },
        { provide: CreatePrivatePlanUseCase, useValue: mockCreateUseCase },
        { provide: PlanSelectCropPresenter, useValue: mockPresenter },
        { provide: Router, useValue: mockRouter },
        { provide: ActivatedRoute, useValue: mockRoute }
      ]
    })
      .overrideComponent(PlanSelectCropComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(PlanSelectCropComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should initialize presenter and load context on init with farmId', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ farmId: 1 });
  });

  it('should show error when farmId is missing', () => {
    mockRoute.snapshot.queryParams = {};

    component.ngOnInit();

    expect(component.control.error).toBe('農場IDが指定されていません');
    expect(component.control.loading).toBe(false);
  });

  it('should navigate to optimizing page on plan created', () => {
    component.onPlanCreated(123);

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans', 123, 'optimizing']);
  });

  it('should update control on plan create error', () => {
    component.onPlanCreateError('作成エラー');

    expect(component.control.error).toBe('作成エラー');
    expect(component.control.creating).toBe(false);
  });
});
