import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanCreatePresenter } from './public-plan-create.presenter';
import { PublicPlanCreateView } from '../../components/public-plans/public-plan-create.view';

describe('PublicPlanCreatePresenter', () => {
  let presenter: PublicPlanCreatePresenter;
  let viewMock: PublicPlanCreateView;

  beforeEach(() => {
    viewMock = {
      control: {
        loading: true,
        error: null,
        farms: []
      }
    };

    presenter = new PublicPlanCreatePresenter();
    presenter.setView(viewMock);
  });

  it('sets loading to false and updates farms when present is called', () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.6762, longitude: 139.6503 }];

    presenter.present({ farms });

    expect(viewMock.control.loading).toBe(false);
    expect(viewMock.control.error).toBe(null);
    expect(viewMock.control.farms).toEqual(farms);
  });

  it('sets loading to false and sets error when onError is called', () => {
    presenter.onError({ message: 'Network error' });

    expect(viewMock.control.loading).toBe(false);
    expect(viewMock.control.error).toBe('Network error');
    expect(viewMock.control.farms).toEqual([]);
  });

  it('updates view control via setter when present is called', () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.6762, longitude: 139.6503 }];
    let setControlValue: unknown = null;
    Object.defineProperty(viewMock, 'control', {
      get: () => ({
        loading: true,
        error: null,
        farms: []
      }),
      set: vi.fn((value) => {
        setControlValue = value;
      })
    });

    presenter.present({ farms });

    expect(setControlValue).toEqual({
      loading: false,
      error: null,
      farms
    });
  });
});
