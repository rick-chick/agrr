import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PesticideListComponent } from './pesticide-list.component';
import { PesticideListPresenter } from '../../../usecase/pesticides/pesticide-list.providers';
import { LoadPesticideListUseCase } from '../../../usecase/pesticides/load-pesticide-list.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { Pesticide } from '../../../domain/pesticides/pesticide';

const pesticideWithIngredient: Pesticide = {
  id: 1,
  name: 'Spray A',
  active_ingredient: 'Imidacloprid',
  is_reference: false,
  crop_id: 1,
  pest_id: 1
};

const pesticideWithoutIngredient: Pesticide = {
  id: 2,
  name: 'Spray B',
  active_ingredient: null,
  is_reference: false,
  crop_id: 1,
  pest_id: 1
};

describe('PesticideListComponent uniform card rows', () => {
  let fixture: ComponentFixture<PesticideListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PesticideListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPesticideListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeletePesticideUseCase, useValue: { execute: vi.fn() } },
        { provide: PesticideListPresenter, useValue: { setView: vi.fn() } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(PesticideListComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(PesticideListComponent);
    fixture.detectChanges();
  });

  function renderPesticides(pesticides: Pesticide[]): HTMLElement {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      errorIsWarmup: false,
      pesticides,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
    return fixture.nativeElement;
  }

  it('uses uniform card layout with single-line title and active ingredient row', () => {
    const el = renderPesticides([pesticideWithIngredient]);
    const body = el.querySelector('.item-card__body') as HTMLElement;
    const title = el.querySelector('.item-card__title--single-line') as HTMLElement;
    const ingredientRow = el.querySelector(
      '.pesticide-list__active-ingredient.item-card__meta--single-line'
    ) as HTMLElement;

    expect(body.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(ingredientRow).toBeTruthy();
    expect(ingredientRow.textContent?.trim()).toBe('Imidacloprid');
  });

  it('keeps active ingredient row in DOM when active_ingredient is absent', () => {
    const el = renderPesticides([pesticideWithoutIngredient]);
    const ingredientRow = el.querySelector('.pesticide-list__active-ingredient') as HTMLElement;
    expect(ingredientRow).toBeTruthy();
    expect(ingredientRow.textContent?.trim()).toBe('');
  });
});
