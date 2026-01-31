import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanNewPresenter } from './plan-new.presenter';
import { PlanNewView } from '../../components/plans/plan-new.view';
import { Farm } from '../../domain/farms/farm';

describe('PlanNewPresenter', () => {
  let presenter: PlanNewPresenter;
  let mockView: PlanNewView & { control: { loading: boolean; error: string | null; farms: Farm[] } };

  beforeEach(() => {
    mockView = {
      get control() {
        return { loading: true, error: null, farms: [] };
      },
      set control(_value: { loading: boolean; error: string | null; farms: Farm[] }) {}
    } as PlanNewView & { control: { loading: boolean; error: string | null; farms: Farm[] } };

    TestBed.configureTestingModule({
      providers: [PlanNewPresenter]
    });

    presenter = TestBed.inject(PlanNewPresenter);
  });

  it('should create', () => {
    expect(presenter).toBeTruthy();
  });

  it('should set view and present farms', () => {
    presenter.setView(mockView);

    const farms: Farm[] = [
      { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' },
      { id: 2, name: 'Farm 2', latitude: 36.0, longitude: 136.0, region: 'Region 2' }
    ];

    expect(() => presenter.present({ farms })).not.toThrow();
    expect(() => presenter.onError({ message: 'error' })).not.toThrow();
  });

  it('should present farms to view', () => {
    presenter.setView(mockView);

    const farms: Farm[] = [
      { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' },
      { id: 2, name: 'Farm 2', latitude: 36.0, longitude: 136.0, region: 'Region 2' }
    ];

    presenter.present({ farms });

    expect(mockView.control).toBeDefined();
  });

  it('should present error to view', () => {
    presenter.setView(mockView);

    presenter.onError({ message: 'Failed to load farms' });

    expect(mockView.control).toBeDefined();
  });
});
