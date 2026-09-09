import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PestListComponent } from './pest-list.component';
import { PestListPresenter } from '../../../usecase/pests/pest-list.providers';
import { LoadPestListUseCase } from '../../../usecase/pests/load-pest-list.usecase';
import { DeletePestUseCase } from '../../../usecase/pests/delete-pest.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { Pest } from '../../../domain/pests/pest';

const pestWithScientific: Pest = {
  id: 1,
  name: 'Aphid',
  name_scientific: 'Aphidoidea',
  is_reference: false
};

const pestWithoutScientific: Pest = {
  id: 2,
  name: 'Thrips',
  name_scientific: null,
  is_reference: false
};

describe('PestListComponent uniform card rows', () => {
  let fixture: ComponentFixture<PestListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PestListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPestListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeletePestUseCase, useValue: { execute: vi.fn() } },
        { provide: PestListPresenter, useValue: { setView: vi.fn() } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(PestListComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(PestListComponent);
    fixture.detectChanges();
  });

  function renderPests(pests: Pest[]): HTMLElement {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pests,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
    return fixture.nativeElement;
  }

  it('uses uniform card layout with single-line title and scientific name row', () => {
    const el = renderPests([pestWithScientific]);
    const body = el.querySelector('.item-card__body') as HTMLElement;
    const title = el.querySelector('.item-card__title--single-line') as HTMLElement;
    const scientificRow = el.querySelector('.pest-list__scientific-name.item-card__meta--single-line') as HTMLElement;

    expect(body.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(scientificRow).toBeTruthy();
    expect(scientificRow.textContent?.trim()).toBe('Aphidoidea');
  });

  it('keeps scientific name row in DOM when name_scientific is absent', () => {
    const el = renderPests([pestWithoutScientific]);
    const scientificRow = el.querySelector('.pest-list__scientific-name') as HTMLElement;
    expect(scientificRow).toBeTruthy();
    expect(scientificRow.textContent?.trim()).toBe('');
  });
});
