import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanResultsPresenter } from './public-plan-results.presenter';
import { PublicPlanResultsView, PublicPlanResultsViewState } from '../../components/public-plans/public-plan-results.view';
import { Router } from '@angular/router';
import { FlashMessageService } from '../../services/flash-message.service';

describe('PublicPlanResultsPresenter', () => {
  let presenter: PublicPlanResultsPresenter;
  let view: PublicPlanResultsView;
  let lastControl: PublicPlanResultsViewState | null;
  let mockRouter: Router & { navigate: ReturnType<typeof vi.fn> };
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockRouter = { navigate: vi.fn() } as Router & { navigate: ReturnType<typeof vi.fn> };
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        PublicPlanResultsPresenter,
        { provide: Router, useValue: mockRouter },
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });

    presenter = TestBed.inject(PublicPlanResultsPresenter);
    lastControl = null;
    view = {
      get control(): PublicPlanResultsViewState {
        return lastControl ?? { loading: true, error: null, data: null };
      },
      set control(value: PublicPlanResultsViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('SavePublicPlanOutputPort', () => {
    it('navigates to plans and shows success message on successful save', () => {
      const dto = { message: 'Plan saved successfully' };

      presenter.present(dto);

      expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans']);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'success', text: 'Plan saved successfully' });
      // View control should not be updated for save success
      expect(lastControl).toBeNull();
    });

    it('updates view.control and shows error message on save error', () => {
      const dto = { message: 'Failed to save plan' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Failed to save plan' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Failed to save plan');
      expect(lastControl!.data).toBeNull();
    });
  });
});