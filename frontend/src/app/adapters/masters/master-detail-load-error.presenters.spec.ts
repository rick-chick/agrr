import { TestBed } from '@angular/core/testing';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import { ErrorDto } from '../../domain/shared/error.dto';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { PestDetailPresenter } from '../pests/pest-detail.presenter';
import { PesticideDetailPresenter } from '../pesticides/pesticide-detail.presenter';
import { AgriculturalTaskDetailPresenter } from '../agricultural-tasks/agricultural-task-detail.presenter';
import { InteractionRuleDetailPresenter } from '../interaction-rules/interaction-rule-detail.presenter';
import { CropEditPresenter } from '../crops/crop-edit.presenter';
import { PestEditPresenter } from '../pests/pest-edit.presenter';
import { PesticideEditPresenter } from '../pesticides/pesticide-edit.presenter';
import { AgriculturalTaskEditPresenter } from '../agricultural-tasks/agricultural-task-edit.presenter';
import { InteractionRuleEditPresenter } from '../interaction-rules/interaction-rule-edit.presenter';
import { FertilizeEditPresenter } from '../fertilizes/fertilize-edit.presenter';

type WarmupViewControl = {
  loading: boolean;
  saving?: boolean;
  error: string | null;
  errorIsWarmup?: boolean;
  pendingErrorFlash: unknown;
  [key: string]: unknown;
};

type PresenterCase = {
  name: string;
  presenterClass:
    | typeof PestDetailPresenter
    | typeof PesticideDetailPresenter
    | typeof AgriculturalTaskDetailPresenter
    | typeof InteractionRuleDetailPresenter
    | typeof CropEditPresenter
    | typeof PestEditPresenter
    | typeof PesticideEditPresenter
    | typeof AgriculturalTaskEditPresenter
    | typeof InteractionRuleEditPresenter
    | typeof FertilizeEditPresenter;
  needsListRefreshBus: boolean;
  loadingControl: WarmupViewControl;
};

const mockListRefreshBus = {
  refresh: vi.fn(),
  onRefresh: vi.fn(() => () => {})
};

const cases: PresenterCase[] = [
  {
    name: 'PestDetailPresenter',
    presenterClass: PestDetailPresenter,
    needsListRefreshBus: true,
    loadingControl: {
      loading: true,
      error: null,
      errorIsWarmup: false,
      pest: null,
      pendingUndoToast: null,
      pendingErrorFlash: null
    }
  },
  {
    name: 'PesticideDetailPresenter',
    presenterClass: PesticideDetailPresenter,
    needsListRefreshBus: true,
    loadingControl: {
      loading: true,
      error: null,
      errorIsWarmup: false,
      pesticide: null,
      pendingUndoToast: null,
      pendingErrorFlash: null
    }
  },
  {
    name: 'AgriculturalTaskDetailPresenter',
    presenterClass: AgriculturalTaskDetailPresenter,
    needsListRefreshBus: true,
    loadingControl: {
      loading: true,
      error: null,
      errorIsWarmup: false,
      task: null,
      pendingUndoToast: null,
      pendingErrorFlash: null
    }
  },
  {
    name: 'InteractionRuleDetailPresenter',
    presenterClass: InteractionRuleDetailPresenter,
    needsListRefreshBus: true,
    loadingControl: {
      loading: true,
      error: null,
      errorIsWarmup: false,
      rule: null,
      pendingUndoToast: null,
      pendingErrorFlash: null
    }
  },
  {
    name: 'CropEditPresenter',
    presenterClass: CropEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        name: '',
        variety: null,
        area_per_unit: null,
        revenue_per_area: null,
        region: null,
        groups: [],
        groupsDisplay: '',
        is_reference: false
      }
    }
  },
  {
    name: 'PestEditPresenter',
    presenterClass: PestEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      formData: { name: '', is_reference: false }
    }
  },
  {
    name: 'PesticideEditPresenter',
    presenterClass: PesticideEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      formData: {
        name: '',
        crop_id: null,
        pest_id: null,
        is_reference: false
      }
    }
  },
  {
    name: 'AgriculturalTaskEditPresenter',
    presenterClass: AgriculturalTaskEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      formData: { name: '', is_reference: false, task_type: 'field_work' }
    }
  },
  {
    name: 'InteractionRuleEditPresenter',
    presenterClass: InteractionRuleEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      formData: {
        source_group: '',
        target_group: '',
        impact_ratio: null,
        is_directional: true,
        description: null
      }
    }
  },
  {
    name: 'FertilizeEditPresenter',
    presenterClass: FertilizeEditPresenter,
    needsListRefreshBus: false,
    loadingControl: {
      loading: true,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: null,
      formData: {
        name: '',
        n: null,
        p: null,
        k: null,
        description: null,
        package_size: null,
        region: null
      }
    }
  }
];

describe.each(cases)('$name warmup load error handling', ({ presenterClass, needsListRefreshBus, loadingControl }) => {
  let presenter: { setView: (view: { control: WarmupViewControl; reload?: () => void }) => void; onError: (dto: ErrorDto) => void };
  let lastControl: WarmupViewControl | null;

  beforeEach(() => {
    const providers: unknown[] = [presenterClass];
    if (needsListRefreshBus) {
      providers.push({ provide: ListRefreshBus, useValue: mockListRefreshBus });
    }
    TestBed.configureTestingModule({ providers });
    presenter = TestBed.inject(presenterClass as never) as typeof presenter;
    lastControl = null;
    presenter.setView({
      get control(): WarmupViewControl {
        return lastControl ?? loadingControl;
      },
      set control(value: WarmupViewControl) {
        lastControl = value;
      },
      reload: vi.fn()
    });
  });

  it('sets errorIsWarmup true on warmup load failure while loading', () => {
    lastControl = { ...loadingControl };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/example/1: 503 Service Unavailable'
    });

    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl!.errorIsWarmup).toBe(true);
    expect(lastControl!.pendingErrorFlash).toBeNull();
  });
});
