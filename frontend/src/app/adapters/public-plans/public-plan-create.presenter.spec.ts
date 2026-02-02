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
        farms: [],
        farmSizes: []
      }
    };

    presenter = new PublicPlanCreatePresenter();
    presenter.setView(viewMock);
  });

  // REDテスト: presentが呼ばれたときにloadingがfalseになり、データが設定される
  it('sets loading to false and updates data when present is called', () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.6762, longitude: 139.6503 }];
    const farmSizes = [{ id: 'home_garden', name: 'Home Garden', area_sqm: 30, description: 'Home garden description' }];

    presenter.present({
      farms,
      farmSizes
    });

    expect(viewMock.control.loading).toBe(false);
    expect(viewMock.control.error).toBe(null);
    expect(viewMock.control.farms).toEqual(farms);
    expect(viewMock.control.farmSizes).toEqual(farmSizes);
  });

  // REDテスト: onErrorが呼ばれたときにloadingがfalseになり、エラーが設定される
  it('sets loading to false and sets error when onError is called', () => {
    presenter.onError({ message: 'Network error' });

    expect(viewMock.control.loading).toBe(false);
    expect(viewMock.control.error).toBe('Network error');
    expect(viewMock.control.farms).toEqual([]);
    // farmSizesは前の状態を保持
    expect(viewMock.control.farmSizes).toEqual([]);
  });

  // INTEGRATIONテスト: Viewのcontrolプロパティが正しく更新されるか確認
  it('integration test - view control property is updated correctly', () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.6762, longitude: 139.6503 }];
    const farmSizes = [{ id: 'home_garden', name: 'Home Garden', area_sqm: 30, description: 'Home garden description' }];

    // Viewのcontrol getter/setterをスパイ
    let setControlValue: any = null;
    Object.defineProperty(viewMock, 'control', {
      get: () => ({
        loading: true,
        error: null,
        farms: [],
        farmSizes: []
      }),
      set: vi.fn((value) => { setControlValue = value; })
    });

    presenter.present({
      farms,
      farmSizes
    });

    // control setterが呼ばれたことを確認
    expect(setControlValue).toEqual({
      loading: false,
      error: null,
      farms,
      farmSizes
    });
  });
});