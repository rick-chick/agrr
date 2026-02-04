import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanNewComponent } from './plan-new.component';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';

describe('PlanNewComponent', () => {
  let component: PlanNewComponent;
  let fixture: ComponentFixture<PlanNewComponent>;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockRouter: { navigate: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockRouter = { navigate: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [PlanNewComponent, TranslateModule.forRoot()],
      providers: [
        { provide: LoadPrivatePlanFarmsUseCase, useValue: mockUseCase },
        { provide: PlanNewPresenter, useValue: mockPresenter },
        { provide: Router, useValue: mockRouter }
      ]
    })
      .overrideComponent(PlanNewComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(PlanNewComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should initialize presenter and load farms on init', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockUseCase.execute).toHaveBeenCalled();
  });

  it('should navigate to select-crop on farm selection', () => {
    fixture.detectChanges();
    const mockForm = document.createElement('form');
    const mockSelect = document.createElement('select');
    mockSelect.setAttribute('name', 'farmId');
    const option = document.createElement('option');
    option.value = '1';
    option.selected = true;
    mockSelect.appendChild(option);
    mockForm.appendChild(mockSelect);
    const mockEvent = {
      preventDefault: vi.fn(),
      target: mockForm
    } as unknown as Event;

    component.onFarmSelect(mockEvent);

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans/select-crop'], { queryParams: { farmId: '1' } });
  });
});
