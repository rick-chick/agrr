import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropListComponent } from './crop-list.component';
import { Crop } from '../../../domain/crops/crop';
import { CropListPresenter } from '../../../usecase/crops/crop-list.providers';
import { LoadCropListUseCase } from '../../../usecase/crops/load-crop-list.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
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
      inline: {
        stages_toggle: 'Growth stages',
        blueprints_toggle: 'Edit task plans'
      }
    },
    show: {
      reference_crop: 'Reference crop'
    }
  },
  common: {
    loading: 'Loading…',
    edit: 'Edit',
    delete: 'Delete',
    actions: 'Actions'
  }
};

describe('CropListComponent card actions', () => {
  let fixture: ComponentFixture<CropListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CropListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        CropListPresenter,
        { provide: LoadCropListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteCropUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: () => ({ admin: false }) } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(CropListComponent, { set: { providers: [] } })
      .compileComponents();

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

  it('uses standard item-card layout with edit and delete actions', () => {
    const card = firstCropCard();
    expect(card.querySelector('article.item-card')).not.toBeNull();
    expect(card.querySelector('.item-card__body .item-card__title')?.textContent?.trim()).toBe('Tomato');
    expect(card.querySelector('.item-card__actions .btn-secondary')?.textContent?.trim()).toBe('Edit');
    expect(card.querySelector('.item-card__actions .btn-danger')?.textContent?.trim()).toBe('Delete');
  });

  it('shows overflow menu trigger on each card without inline expansion controls', () => {
    const cards = fixture.nativeElement.querySelectorAll('.card-list__item');
    expect(cards.length).toBe(2);
    for (const card of cards) {
      expect(card.querySelector('[data-testid="crop-overflow-menu-trigger"]')).not.toBeNull();
    }
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-stages-panel"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-blueprints-panel"]')).toBeNull();
  });

  it('opens overflow menu with navigation links when trigger is clicked', () => {
    const trigger = firstCropCard().querySelector(
      '[data-testid="crop-overflow-menu-trigger"]'
    ) as HTMLButtonElement;

    trigger.click();
    fixture.detectChanges();

    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    const stagesLink = firstCropCard().querySelector(
      '[data-testid="crop-stages-link"]'
    ) as HTMLAnchorElement;
    const blueprintsLink = firstCropCard().querySelector(
      '[data-testid="crop-blueprints-link"]'
    ) as HTMLAnchorElement;

    expect(stagesLink?.textContent?.trim()).toBe('Growth stages');
    expect(stagesLink?.getAttribute('href')).toBe('/crops/10/stages');
    expect(blueprintsLink?.textContent?.trim()).toBe('Edit task plans');
    expect(blueprintsLink?.getAttribute('href')).toBe('/crops/10/task_schedule_blueprints');
  });

  it('closes overflow menu when the same trigger is clicked again', () => {
    const trigger = firstCropCard().querySelector(
      '[data-testid="crop-overflow-menu-trigger"]'
    ) as HTMLButtonElement;

    trigger.click();
    fixture.detectChanges();
    trigger.click();
    fixture.detectChanges();

    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('[data-testid="crop-overflow-menu-panel"]')).toBeNull();
  });

  it('closes overflow menu when clicking outside', () => {
    const trigger = firstCropCard().querySelector(
      '[data-testid="crop-overflow-menu-trigger"]'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    document.body.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="crop-overflow-menu-panel"]')).toBeNull();
  });

  it('closes overflow menu when Escape is pressed', () => {
    const trigger = firstCropCard().querySelector(
      '[data-testid="crop-overflow-menu-trigger"]'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="crop-overflow-menu-panel"]')).toBeNull();
  });
});
