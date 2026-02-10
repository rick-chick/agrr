import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { CreatePrivatePlanPresenter, CreatePrivatePlanView } from './create-private-plan.presenter';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { Router } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';

describe('CreatePrivatePlanPresenter', () => {
  let presenter: CreatePrivatePlanPresenter;
  let view: CreatePrivatePlanView;
  let lastControl: any;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };
  let mockTranslateService: TranslateService & { instant: ReturnType<typeof vi.fn> };
  let mockRouter: Router & { navigate: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };
    mockTranslateService = { instant: vi.fn(() => 'translated success') } as TranslateService & { instant: ReturnType<typeof vi.fn> };
    mockRouter = { navigate: vi.fn() } as Router & { navigate: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        CreatePrivatePlanPresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService },
        { provide: Router, useValue: mockRouter },
        { provide: TranslateService, useValue: mockTranslateService }
      ]
    });
    presenter = TestBed.inject(CreatePrivatePlanPresenter);

    lastControl = null;
    view = {
      get control() {
        return lastControl ?? { loading: true, error: null };
      },
      set control(value: any) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('CreatePrivatePlanOutputPort', () => {
    it('shows success message and navigates to optimizing page on present(dto)', () => {
      const dto: CreatePrivatePlanResponseDto = { id: 123 };

      presenter.present(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockTranslateService.instant).toHaveBeenCalledWith('adapters.privatePlanCreate.flash.success');
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({
        type: 'success',
        text: 'translated success'
      });
      expect(mockRouter.navigate).toHaveBeenCalledTimes(1);
      expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans', 123, 'optimizing']);
      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl = { loading: true, error: null };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Validation error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
    });

  });
});