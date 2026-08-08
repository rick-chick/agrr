import { TestBed } from '@angular/core/testing';
import { InteractionRuleEditPresenter } from './interaction-rule-edit.presenter';
import {
  InteractionRuleEditView,
  InteractionRuleEditViewState
} from '../../components/masters/interaction-rules/interaction-rule-edit.view';

describe('InteractionRuleEditPresenter', () => {
  let presenter: InteractionRuleEditPresenter;
  let lastControl: InteractionRuleEditViewState | null;

  const emptyFormData: InteractionRuleEditViewState['formData'] = {
    rule_type: 'competition',
    source_group: '',
    target_group: '',
    impact_ratio: 1,
    is_directional: true,
    description: null,
    region: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [InteractionRuleEditPresenter]
    });
    presenter = TestBed.inject(InteractionRuleEditPresenter);
    lastControl = null;
    const view: InteractionRuleEditView = {
      get control(): InteractionRuleEditViewState {
        return (
          lastControl ?? {
            loading: true,
            saving: false,
            error: null,
            pendingErrorFlash: null,
            formData: emptyFormData
          }
        );
      },
      set control(value: InteractionRuleEditViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('maps raw HTTP 404 text to i18n key on onError(dto)', () => {
    lastControl = {
      loading: true,
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: emptyFormData
    };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/interaction_rules/1: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
    expect(lastControl!.loading).toBe(false);
  });
});
