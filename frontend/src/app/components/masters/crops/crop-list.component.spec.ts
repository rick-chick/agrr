import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropListComponent } from './crop-list.component';
import { Crop } from '../../../domain/crops/crop';
import { CropListPresenter } from '../../../usecase/crops/crop-list.providers';
import { LoadCropListUseCase } from '../../../usecase/crops/load-crop-list.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { AuthService } from '../../../services/auth.service';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';

const userCrop: Crop = {
  id: 10,
  name: 'Tomato',
  variety: 'Momotaro',
  is_reference: false,
  groups: []
};

const referenceCrop: Crop = {
  id: 20,
  name: 'Rice',
  variety: null,
  is_reference: true,
  groups: [],
  crop_stages: [
    {
      id: 1,
      crop_id: 20,
      name: 'Seedling',
      order: 1,
      temperature_requirement: {
        id: 1,
        crop_stage_id: 1,
        base_temperature: 10,
        optimal_min: 15,
        optimal_max: 25
      }
    }
  ]
};

const translations = {
  crops: {
    index: {
      title: 'Crops',
      description: 'Manage crops',
      new_crop: 'Add crop',
      actions: {
        show: 'Details',
        edit: 'Edit',
        delete: 'Delete'
      },
      inline: {
        stages_toggle: 'Growth stages',
        blueprints_toggle: 'Edit task plans',
        collapse: 'Collapse',
        stages_full_edit: 'Edit growth stages',
        blueprints_full_edit: 'Edit task plans'
      }
    },
    show: {
      reference_crop: 'Reference crop',
      no_stages_description: 'No growth stages yet.',
      celsius_unit: '°C',
      blueprint_readiness: {
        detail_title: 'Setup status',
        stages_ready: 'Stages ready',
        stages_missing: 'Stages missing',
        blueprints_ready: 'Task plans ready',
        blueprints_missing: 'Task plans missing'
      },
      blueprint_summary: {
        count: '{{count}} task plans',
        attention_suffix: '({{count}} need attention)',
        setup_required: 'Complete setup before generating schedules.'
      }
    },
    edit: {
      reference_stages_readonly: 'Reference crop stages are read-only.',
      table_order: 'Order',
      table_optimal_range: 'Optimal range',
      value_missing: '—'
    }
  },
  common: {
    loading: 'Loading…',
    edit: 'Edit',
    delete: 'Delete'
  }
};

describe('CropListComponent inline expansion', () => {
  let fixture: ComponentFixture<CropListComponent>;
  let loadCropForEditUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadCropForEditUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [CropListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        CropListPresenter,
        { provide: LoadCropListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteCropUseCase, useValue: { execute: vi.fn() } },
        { provide: LoadCropForEditUseCase, useValue: loadCropForEditUseCase },
        { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase },
        { provide: AuthService, useValue: { user: () => ({ admin: false }) } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(CropListComponent, { set: { providers: [] } })
      .compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: loadCropForEditUseCase });
    TestBed.overrideProvider(LoadCropTaskScheduleBlueprintsUseCase, { useValue: loadBlueprintsUseCase });

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', translations, true);
    translate.use('en');

    fixture = TestBed.createComponent(CropListComponent);
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      crops: [userCrop, referenceCrop],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
  });

  function firstCropCard(): HTMLElement {
    const cards = fixture.nativeElement.querySelectorAll('.card-list__item');
    return cards[0] as HTMLElement;
  }

  it('shows detail, stages, and blueprints actions on each card', () => {
    expect(fixture.componentInstance.control.loading).toBe(false);
    expect(fixture.componentInstance.control.crops.length).toBe(2);
    const cards = fixture.nativeElement.querySelectorAll('.card-list__item');
    expect(cards.length).toBe(2);
    const card = firstCropCard();
    expect(card.querySelector('[data-testid="crop-detail-link"]')?.textContent?.trim()).toBe('Details');
    expect(card.querySelector('[data-testid="crop-stages-toggle"]')?.textContent?.trim()).toBe(
      'Growth stages'
    );
    expect(card.querySelector('[data-testid="crop-blueprints-toggle"]')?.textContent?.trim()).toBe(
      'Edit task plans'
    );
  });

  it('does not render inline panels before toggle', () => {
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-stages-panel"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-blueprints-panel"]')).toBeNull();
  });

  it('expands stages panel with aria-expanded when stages toggle is clicked', () => {
    const toggle = firstCropCard().querySelector(
      '[data-testid="crop-stages-toggle"]'
    ) as HTMLButtonElement;

    toggle.click();
    fixture.detectChanges();

    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-stages-panel"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-blueprints-panel"]')).toBeNull();
  });

  it('expands blueprints panel when blueprints toggle is clicked', () => {
    const toggle = firstCropCard().querySelector(
      '[data-testid="crop-blueprints-toggle"]'
    ) as HTMLButtonElement;

    toggle.click();
    fixture.detectChanges();

    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-blueprints-panel"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-stages-panel"]')).toBeNull();
  });

  it('collapses panel when the same toggle is clicked again', () => {
    const toggle = firstCropCard().querySelector(
      '[data-testid="crop-stages-toggle"]'
    ) as HTMLButtonElement;

    toggle.click();
    fixture.detectChanges();
    toggle.click();
    fixture.detectChanges();

    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-stages-panel"]')).toBeNull();
  });

  it('lazy-loads crop data when stages panel opens', () => {
    const toggle = firstCropCard().querySelector(
      '[data-testid="crop-stages-toggle"]'
    ) as HTMLButtonElement;

    toggle.click();
    fixture.detectChanges();

    expect(loadCropForEditUseCase.execute).toHaveBeenCalledWith({ cropId: userCrop.id });
  });

  it('lazy-loads crop and blueprint data when blueprints panel opens', () => {
    const toggle = firstCropCard().querySelector(
      '[data-testid="crop-blueprints-toggle"]'
    ) as HTMLButtonElement;

    toggle.click();
    fixture.detectChanges();

    expect(loadCropForEditUseCase.execute).toHaveBeenCalledWith({ cropId: userCrop.id });
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: userCrop.id });
  });
});
