import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FertilizeListComponent } from './fertilize-list.component';
import { FertilizeListPresenter } from '../../../usecase/fertilizes/fertilize-list.providers';
import { LoadFertilizeListUseCase } from '../../../usecase/fertilizes/load-fertilize-list.usecase';
import { DeleteFertilizeUseCase } from '../../../usecase/fertilizes/delete-fertilize.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { Fertilize } from '../../../domain/fertilizes/fertilize';

const fertilize: Fertilize = {
  id: 1,
  name: 'NPK Mix',
  n: 10,
  p: 5,
  k: 5,
  is_reference: false
};

describe('FertilizeListComponent uniform card rows', () => {
  let fixture: ComponentFixture<FertilizeListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FertilizeListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadFertilizeListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteFertilizeUseCase, useValue: { execute: vi.fn() } },
        { provide: FertilizeListPresenter, useValue: { setView: vi.fn() } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } }
      ]
    })
      .overrideComponent(FertilizeListComponent, { set: { providers: [] } })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      fertilizes: { show: { npk_summary: 'NPK' } }
    });
    translate.use('en');

    fixture = TestBed.createComponent(FertilizeListComponent);
    fixture.detectChanges();
  });

  it('uses uniform card layout with single-line title and NPK meta row', () => {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      fertilizes: [fertilize],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const el = fixture.nativeElement;
    const body = el.querySelector('.item-card__body') as HTMLElement;
    const title = el.querySelector('.item-card__title--single-line') as HTMLElement;
    const npkRow = el.querySelector('.fertilize-list__npk.item-card__meta--single-line') as HTMLElement;

    expect(body.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(npkRow).toBeTruthy();
    expect(npkRow.textContent).toContain('10/5/5');
  });
});
