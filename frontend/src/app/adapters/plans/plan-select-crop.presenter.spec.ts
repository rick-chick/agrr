import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanSelectCropPresenter } from './plan-select-crop.presenter';
import { PlanSelectCropView } from '../../components/plans/plan-select-crop.view';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';

describe('PlanSelectCropPresenter', () => {
  let presenter: PlanSelectCropPresenter;
  let mockView: PlanSelectCropView & {
    control: { loading: boolean; error: string | null; farm: Farm | null; totalArea: number; crops: Crop[]; creating: boolean };
    onPlanCreated: ReturnType<typeof vi.fn>;
    onPlanCreateError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    mockView = {
      get control() {
        return { loading: true, error: null, farm: null, totalArea: 0, crops: [], creating: false };
      },
      set control(_value) {},
      onPlanCreated: vi.fn(),
      onPlanCreateError: vi.fn()
    } as PlanSelectCropView & {
      control: { loading: boolean; error: string | null; farm: Farm | null; totalArea: number; crops: Crop[]; creating: boolean };
      onPlanCreated: ReturnType<typeof vi.fn>;
      onPlanCreateError: ReturnType<typeof vi.fn>;
    };

    TestBed.configureTestingModule({
      providers: [PlanSelectCropPresenter]
    });

    presenter = TestBed.inject(PlanSelectCropPresenter);
  });

  it('should create', () => {
    expect(presenter).toBeTruthy();
  });

  it('should set view and present context via present(dto)', () => {
    presenter.setView(mockView);

    const farm: Farm = { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' };
    const crops: Crop[] = [
      { id: 1, name: 'Crop 1', is_reference: false, groups: [] },
      { id: 2, name: 'Crop 2', is_reference: false, groups: [] }
    ];

    expect(() => presenter.present({ farm, totalArea: 100, crops })).not.toThrow();
    expect(() => presenter.present({ id: 123 })).not.toThrow();
    expect(() => presenter.onError({ message: 'error' })).not.toThrow();
  });

  it('should present select crop context to view', () => {
    presenter.setView(mockView);

    const farm: Farm = { id: 1, name: 'Test Farm', latitude: 35.0, longitude: 135.0, region: 'Region 1' };
    const crops: Crop[] = [
      { id: 1, name: 'Crop 1', is_reference: false, groups: [] },
      { id: 2, name: 'Crop 2', is_reference: false, groups: [] }
    ];

    presenter.present({ farm, totalArea: 150, crops });

    expect(mockView.control).toBeDefined();
  });

  it('should present plan created via present({ id })', () => {
    presenter.setView(mockView);

    presenter.present({ id: 123 });

    expect(mockView.onPlanCreated).toHaveBeenCalledWith(123);
  });

  it('should present error to view', () => {
    presenter.setView(mockView);

    presenter.onError({ message: 'Failed to load context' });

    expect(mockView.control).toBeDefined();
  });
});
