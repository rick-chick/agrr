import { TestBed } from '@angular/core/testing';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropListPresenter } from '../crops/crop-list.presenter';
import { PestListPresenter } from '../pests/pest-list.presenter';
import { PesticideListPresenter } from '../pesticides/pesticide-list.presenter';
import { FertilizeListPresenter } from '../fertilizes/fertilize-list.presenter';
import { InteractionRuleListPresenter } from '../interaction-rules/interaction-rule-list.presenter';
import { AgriculturalTaskListPresenter } from '../agricultural-tasks/agricultural-task-list.presenter';

type ListViewControl = {
  loading: boolean;
  error: string | null;
  pendingUndoToast: unknown;
  pendingErrorFlash: unknown;
};

type PresenterCase = {
  name: string;
  presenterClass:
    | typeof CropListPresenter
    | typeof PestListPresenter
    | typeof PesticideListPresenter
    | typeof FertilizeListPresenter
    | typeof InteractionRuleListPresenter
    | typeof AgriculturalTaskListPresenter;
  emptyControl: ListViewControl;
};

const cases: PresenterCase[] = [
  {
    name: 'CropListPresenter',
    presenterClass: CropListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  },
  {
    name: 'PestListPresenter',
    presenterClass: PestListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  },
  {
    name: 'PesticideListPresenter',
    presenterClass: PesticideListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  },
  {
    name: 'FertilizeListPresenter',
    presenterClass: FertilizeListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  },
  {
    name: 'InteractionRuleListPresenter',
    presenterClass: InteractionRuleListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  },
  {
    name: 'AgriculturalTaskListPresenter',
    presenterClass: AgriculturalTaskListPresenter,
    emptyControl: { loading: true, error: null, pendingUndoToast: null, pendingErrorFlash: null }
  }
];

describe.each(cases)('$name load error handling', ({ presenterClass, emptyControl }) => {
  let presenter: { setView: (view: { control: ListViewControl }) => void; onError: (dto: ErrorDto) => void };
  let lastControl: ListViewControl | null;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [presenterClass] });
    presenter = TestBed.inject(presenterClass as never) as {
      setView: (view: { control: ListViewControl }) => void;
      onError: (dto: ErrorDto) => void;
    };
    lastControl = null;
    presenter.setView({
      get control(): ListViewControl {
        return lastControl ?? emptyControl;
      },
      set control(value: ListViewControl) {
        lastControl = value;
      }
    });
  });

  it('sets control.error i18n key on load failure while loading', () => {
    lastControl = { ...emptyControl };

    presenter.onError({ message: 'Something went wrong' });

    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBe('common.api_error.generic');
    expect(lastControl!.pendingErrorFlash).toBeNull();
  });

  it('queues pending error flash without control.error when not loading', () => {
    lastControl = { loading: false, error: null, pendingUndoToast: null, pendingErrorFlash: null };

    presenter.onError({ message: 'Delete failed' });

    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Delete failed' });
  });
});
