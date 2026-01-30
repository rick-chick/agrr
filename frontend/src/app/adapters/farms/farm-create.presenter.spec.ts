import { FarmCreatePresenter } from './farm-create.presenter';
import { FarmCreateView, FarmCreateViewState } from '../../components/masters/farms/farm-create.view';
import { CreateFarmSuccessDto } from '../../usecase/farms/create-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

describe('FarmCreatePresenter', () => {
  let presenter: FarmCreatePresenter;
  let view: FarmCreateView;
  let lastControl: FarmCreateViewState | null;

  beforeEach(() => {
    presenter = new FarmCreatePresenter();
    lastControl = null;
    view = {
      get control(): FarmCreateViewState {
        return lastControl ?? { saving: false, error: null, formData: { name: '', region: '', latitude: 0, longitude: 0 } };
      },
      set control(value: FarmCreateViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('CreateFarmOutputPort', () => {
    it('does not update view.control on onSuccess(dto)', () => {
      const initialControl: FarmCreateViewState = { saving: true, error: null, formData: { name: 'New Farm', region: 'Region', latitude: 35.0, longitude: 135.0 } };
      lastControl = initialControl;

      const dto: CreateFarmSuccessDto = {
        farm: {
          id: 1,
          name: 'New Farm',
          region: 'Region',
          latitude: 35.0,
          longitude: 135.0,
          weather_data_status: 'pending'
        }
      };

      presenter.onSuccess(dto);

      // onSuccess does not update view.control
      expect(lastControl).toEqual(initialControl);
    });

    it('updates view.control on onError(dto)', () => {
      const initialControl: FarmCreateViewState = { saving: true, error: null, formData: { name: 'New Farm', region: 'Region', latitude: 35.0, longitude: 135.0 } };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.error).toBe('Validation error');
      expect(lastControl!.formData).toEqual(initialControl.formData); // formData preserved
    });
  });
});