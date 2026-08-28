import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { InteractionRuleDetailPresenter } from './interaction-rule-detail.presenter';
import {
  InteractionRuleDetailView,
  InteractionRuleDetailViewState
} from '../../components/masters/interaction-rules/interaction-rule-detail.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';

describe('InteractionRuleDetailPresenter', () => {
  let presenter: InteractionRuleDetailPresenter;
  let lastControl: InteractionRuleDetailViewState | null;
  let mockListRefreshBus: ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockListRefreshBus = {
      refresh: vi.fn(),
      onRefresh: vi.fn(() => () => {})
    } as unknown as ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        InteractionRuleDetailPresenter,
        { provide: ListRefreshBus, useValue: mockListRefreshBus }
      ]
    });
    presenter = TestBed.inject(InteractionRuleDetailPresenter);
    lastControl = null;
    const view: InteractionRuleDetailView = {
      get control(): InteractionRuleDetailViewState {
        return lastControl ?? { loading: true, error: null, rule: null, pendingUndoToast: null, pendingErrorFlash: null };
      },
      set control(value: InteractionRuleDetailViewState) {
        lastControl = value;
      },
      reload: vi.fn()
    };
    presenter.setView(view);
  });

  it('sets inline error key on onError(dto) while loading', () => {
    lastControl = { loading: true, error: null, rule: null, pendingUndoToast: null, pendingErrorFlash: null };
    const dto: ErrorDto = { message: 'common.api_error.not_found' };

    presenter.onError(dto);

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.pendingErrorFlash).toBeNull();
    expect(lastControl!.loading).toBe(false);
  });

  it('maps raw HTTP error text to i18n key on onError(dto) while loading', () => {
    lastControl = { loading: true, error: null, rule: null, pendingUndoToast: null, pendingErrorFlash: null };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/interaction_rules/999: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
  });

  it('queues pending error flash on onError(dto) when not loading', () => {
    lastControl = {
      loading: false,
      error: null,
      rule: {
        id: 1,
        rule_type: 'competition',
        source_group: 'legume',
        target_group: 'cereal',
        impact_ratio: 0.5,
        is_directional: true,
        is_reference: false,
        region: null
      },
      pendingUndoToast: null,
      pendingErrorFlash: null
    };

    presenter.onError({ message: 'Not found' });

    expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'common.api_error.not_found' });
    expect(lastControl!.error).toBeNull();
  });

  describe('DeleteInteractionRuleOutputPort', () => {
    it('queues pending undo toast with list refresh callback on onSuccess(dto)', () => {
      lastControl = {
        loading: false,
        error: null,
        rule: {
          id: 1,
          rule_type: 'competition',
          source_group: 'legume',
          target_group: 'cereal',
          impact_ratio: 0.5,
          is_directional: true,
          is_reference: false,
          region: null
        },
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeleteInteractionRuleSuccessDto = {
        deletedInteractionRuleId: 1,
        undo: {
          undo_token: 'token123',
          toast_message: 'Rule deleted',
          undo_path: '/undo_deletion',
          resource: 'legume → cereal'
        }
      };

      presenter.onSuccess(dto);

      expect(lastControl!.pendingUndoToast).toEqual({
        message: 'Rule deleted',
        undoPath: '/undo_deletion',
        undoToken: 'token123',
        onRestored: expect.any(Function),
        resourceLabel: 'legume → cereal'
      });
      lastControl!.pendingUndoToast!.onRestored!();
      expect(mockListRefreshBus.refresh).toHaveBeenCalledWith(LIST_REFRESH_CHANNEL.interactionRules);
    });
  });
});
