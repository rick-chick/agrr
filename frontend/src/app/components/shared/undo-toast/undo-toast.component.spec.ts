import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import { UndoToastComponent } from './undo-toast.component';
import { UndoToastService } from '../../../services/undo-toast.service';

describe('UndoToastComponent', () => {
  let fixture: ComponentFixture<UndoToastComponent>;
  let translate: TranslateService;
  let mockToastService: UndoToastService & {
    state: ReturnType<typeof vi.fn>;
    hide: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    mockToastService = {
      state: vi.fn(() => ({ visible: true, message: 'Farm was deleted.' })),
      hide: vi.fn()
    } as UndoToastService & {
      state: ReturnType<typeof vi.fn>;
      hide: ReturnType<typeof vi.fn>;
    };

    await TestBed.configureTestingModule({
      imports: [UndoToastComponent, TranslateModule.forRoot()],
      providers: [{ provide: UndoToastService, useValue: mockToastService }]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      deletion_undo: {
        undo_button: 'Undo',
        close_button: 'Close'
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(UndoToastComponent);
    fixture.detectChanges();
  });

  it('renders deletion_undo.undo_button and close_button via translate', () => {
    const buttons = fixture.nativeElement.querySelectorAll('button');
    expect(buttons.length).toBe(2);
    expect(buttons[0]?.textContent?.trim()).toBe('Undo');
    expect(buttons[1]?.textContent?.trim()).toBe('Close');
  });

  it('uses design-system button classes on undo and close actions', () => {
    const buttons = fixture.nativeElement.querySelectorAll('.undo-toast .actions button');
    expect(buttons.length).toBe(2);
    for (const button of buttons) {
      expect(button.classList.contains('btn')).toBe(true);
      expect(button.classList.contains('btn-white')).toBe(true);
      expect(button.classList.contains('btn-sm')).toBe(true);
    }
  });
});
