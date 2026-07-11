import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import { FlashMessageComponent } from './flash-message.component';
import { FlashMessageService } from '../../../services/flash-message.service';

describe('FlashMessageComponent', () => {
  let fixture: ComponentFixture<FlashMessageComponent>;
  let translate: TranslateService;
  let mockFlashService: FlashMessageService & {
    messages: ReturnType<typeof vi.fn>;
    remove: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    mockFlashService = {
      messages: vi.fn(() => [
        { id: '1', type: 'success', text: 'Farm was successfully created.' }
      ]),
      remove: vi.fn()
    } as FlashMessageService & {
      messages: ReturnType<typeof vi.fn>;
      remove: ReturnType<typeof vi.fn>;
    };

    await TestBed.configureTestingModule({
      imports: [FlashMessageComponent, TranslateModule.forRoot()],
      providers: [{ provide: FlashMessageService, useValue: mockFlashService }]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: {
        close: 'Close'
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(FlashMessageComponent);
    fixture.detectChanges();
  });

  it('renders messages in a fixed toast container that does not use inline layout spacing', () => {
    const container = fixture.nativeElement.querySelector('.flash-container');
    expect(container).toBeTruthy();
    expect(getComputedStyle(container).position).toBe('fixed');
  });

  it('renders common.close as the only action button', () => {
    const buttons = fixture.nativeElement.querySelectorAll('.flash-message button');
    expect(buttons.length).toBe(1);
    expect(buttons[0]?.textContent?.trim()).toBe('Close');
    expect(buttons[0]?.getAttribute('aria-label')).toBe('Close');
  });

  it('removes the message when close is clicked', () => {
    const button = fixture.nativeElement.querySelector('.flash-message button');
    button?.click();
    expect(mockFlashService.remove).toHaveBeenCalledWith('1');
  });
});
