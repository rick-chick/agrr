import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanDetailComponent } from './plan-detail.component';
import { PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PlanDetailPresenter } from '../../usecase/plans/plan-detail.providers';

describe('PlanDetailComponent', () => {
  let component: PlanDetailComponent;
  let fixture: ComponentFixture<PlanDetailComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let activatedRoute: {
    snapshot: { paramMap: { get: ReturnType<typeof vi.fn> } };
  };
  let cdr: ChangeDetectorRef;

  beforeEach(() => {
    loadUseCase = { execute: vi.fn(() => of(undefined)) };
    mockPresenter = { setView: vi.fn() };
    activatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '1') }
      }
    };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      imports: [PlanDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: activatedRoute },
        { provide: LoadPlanDetailUseCase, useValue: loadUseCase },
        { provide: PlanDetailPresenter, useValue: mockPresenter }
      ]
    });

    fixture = TestBed.createComponent(PlanDetailComponent);
    component = fixture.componentInstance;
    cdr = (component as unknown as { cdr: ChangeDetectorRef }).cdr;
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
    const markForCheckSpy = vi.spyOn(cdr, 'markForCheck');
    component.control = state;
    expect(component.control).toEqual(state);
    expect(markForCheckSpy).toHaveBeenCalled();
  });

  it('uses the unified plan context header layout', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: {
        id: 1,
        name: 'Plan A',
        status: 'completed',
        farm_id: 1
      },
      planData: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-plan-plan-context-header')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-detail__title')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-context-header__back')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-context-header__identity')).toBeTruthy();
    const forward = fixture.nativeElement.querySelector('.plan-context-header__forward');
    expect(forward?.getAttribute('href')).toContain('/plans/1/work');
  });
});
