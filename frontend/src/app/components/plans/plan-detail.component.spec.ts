import { ChangeDetectorRef } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { of } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanDetailComponent } from './plan-detail.component';
import { PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PlanDetailPresenter } from '../../usecase/plans/plan-detail.providers';

describe('PlanDetailComponent', () => {
  let component: PlanDetailComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let activatedRoute: {
    snapshot: { paramMap: { get: ReturnType<typeof vi.fn> } };
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    loadUseCase = { execute: vi.fn(() => of(undefined)) };
    mockPresenter = { setView: vi.fn() };
    activatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '1') }
      }
    };
    cdr = { markForCheck: vi.fn() };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        PlanDetailComponent,
        { provide: ActivatedRoute, useValue: activatedRoute },
        { provide: LoadPlanDetailUseCase, useValue: loadUseCase },
        { provide: PlanDetailPresenter, useValue: mockPresenter },
        { provide: ChangeDetectorRef, useValue: cdr }
      ]
    });

    component = TestBed.inject(PlanDetailComponent);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('implements View control getter/setter', () => {
    const state: PlanDetailViewState = {
      loading: false,
      error: null,
      plan: null,
      planData: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
    expect(cdr.markForCheck).toHaveBeenCalled();
  });
});
