import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Type, Provider } from '@angular/core';
import { vi } from 'vitest';
import { CropListComponent } from './crops/crop-list.component';
import { PestListComponent } from './pests/pest-list.component';
import { PesticideListComponent } from './pesticides/pesticide-list.component';
import { FertilizeListComponent } from './fertilizes/fertilize-list.component';
import { InteractionRuleListComponent } from './interaction-rules/interaction-rule-list.component';
import { AgriculturalTaskListComponent } from './agricultural-tasks/agricultural-task-list.component';
import { CropListPresenter } from '../../usecase/crops/crop-list.providers';
import { PestListPresenter } from '../../usecase/pests/pest-list.providers';
import { PesticideListPresenter } from '../../usecase/pesticides/pesticide-list.providers';
import { FertilizeListPresenter } from '../../usecase/fertilizes/fertilize-list.providers';
import { InteractionRuleListPresenter } from '../../usecase/interaction-rules/interaction-rule-list.providers';
import { AgriculturalTaskListPresenter } from '../../usecase/agricultural-tasks/agricultural-task-list.providers';
import { LoadCropListUseCase } from '../../usecase/crops/load-crop-list.usecase';
import { LoadPestListUseCase } from '../../usecase/pests/load-pest-list.usecase';
import { LoadPesticideListUseCase } from '../../usecase/pesticides/load-pesticide-list.usecase';
import { LoadFertilizeListUseCase } from '../../usecase/fertilizes/load-fertilize-list.usecase';
import { LoadInteractionRuleListUseCase } from '../../usecase/interaction-rules/load-interaction-rule-list.usecase';
import { LoadAgriculturalTaskListUseCase } from '../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { DeleteCropUseCase } from '../../usecase/crops/delete-crop.usecase';
import { DeletePestUseCase } from '../../usecase/pests/delete-pest.usecase';
import { DeletePesticideUseCase } from '../../usecase/pesticides/delete-pesticide.usecase';
import { DeleteFertilizeUseCase } from '../../usecase/fertilizes/delete-fertilize.usecase';
import { DeleteInteractionRuleUseCase } from '../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { AuthService } from '../../services/auth.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { UndoToastService } from '../../services/undo-toast.service';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';

type ControlState = {
  loading: boolean;
  error: string | null;
  pendingUndoToast: null;
  pendingErrorFlash: null;
};

type ComponentCase = {
  name: string;
  component: Type<unknown>;
  presenter: unknown;
  loadUseCase: unknown;
  deleteUseCase: unknown;
  needsAuth?: boolean;
};

const cases: ComponentCase[] = [
  {
    name: 'CropListComponent',
    component: CropListComponent,
    presenter: CropListPresenter,
    loadUseCase: LoadCropListUseCase,
    deleteUseCase: DeleteCropUseCase,
    needsAuth: true
  },
  {
    name: 'PestListComponent',
    component: PestListComponent,
    presenter: PestListPresenter,
    loadUseCase: LoadPestListUseCase,
    deleteUseCase: DeletePestUseCase
  },
  {
    name: 'PesticideListComponent',
    component: PesticideListComponent,
    presenter: PesticideListPresenter,
    loadUseCase: LoadPesticideListUseCase,
    deleteUseCase: DeletePesticideUseCase
  },
  {
    name: 'FertilizeListComponent',
    component: FertilizeListComponent,
    presenter: FertilizeListPresenter,
    loadUseCase: LoadFertilizeListUseCase,
    deleteUseCase: DeleteFertilizeUseCase
  },
  {
    name: 'InteractionRuleListComponent',
    component: InteractionRuleListComponent,
    presenter: InteractionRuleListPresenter,
    loadUseCase: LoadInteractionRuleListUseCase,
    deleteUseCase: DeleteInteractionRuleUseCase
  },
  {
    name: 'AgriculturalTaskListComponent',
    component: AgriculturalTaskListComponent,
    presenter: AgriculturalTaskListPresenter,
    loadUseCase: LoadAgriculturalTaskListUseCase,
    deleteUseCase: DeleteAgriculturalTaskUseCase
  }
];

describe.each(cases)('$name error/retry UI', ({ component, presenter, loadUseCase, deleteUseCase, needsAuth }) => {
  let fixture: ComponentFixture<{ control: ControlState; load: () => void }>;
  let loadExecute: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    loadExecute = vi.fn();
    const providers: Provider[] = [
      { provide: loadUseCase, useValue: { execute: loadExecute } },
      { provide: deleteUseCase, useValue: { execute: vi.fn() } },
      { provide: presenter, useValue: { setView: vi.fn() } },
      { provide: FlashMessageService, useValue: { show: vi.fn() } },
      { provide: UndoToastService, useValue: { show: vi.fn() } },
      { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
    ];
    if (needsAuth) {
      providers.push({ provide: AuthService, useValue: { user: () => ({ admin: false }) } });
    }

    await TestBed.configureTestingModule({
      imports: [component, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        ...providers
      ]
    })
      .overrideComponent(component, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(component as Type<{ control: ControlState; load: () => void }>);
    fixture.detectChanges();
  });

  it('shows error alert with retry button that calls load()', () => {
    fixture.componentInstance.control = {
      loading: false,
      error: 'common.api_error.generic',
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.page-alert-error[role="alert"]')).toBeTruthy();

    const retryBtn = fixture.nativeElement.querySelector('.master-list__retry') as HTMLButtonElement;
    expect(retryBtn).toBeTruthy();

    const loadSpy = vi.spyOn(fixture.componentInstance, 'load');
    retryBtn.click();
    expect(loadSpy).toHaveBeenCalled();
  });
});
