import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkHubPresenter } from './work-hub.presenter';
import { FlashMessageService } from '../../services/flash-message.service';

describe('WorkHubPresenter', () => {
  let presenter: WorkHubPresenter;
  let navigate: ReturnType<typeof vi.fn>;
  let flashShow: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    navigate = vi.fn();
    flashShow = vi.fn();

    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [
        WorkHubPresenter,
        { provide: Router, useValue: { navigate } },
        { provide: FlashMessageService, useValue: { show: flashShow } }
      ]
    });

    presenter = TestBed.inject(WorkHubPresenter);
    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation('en', { 'plans.messages.plan_created': 'Plan created' }, true);
  });

  it('maps loaded farms to view control', () => {
    const view = {
      control: {
        loading: true,
        submitting: false,
        error: null,
        farms: []
      }
    };
    presenter.setView(view);

    presenter.present({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        }
      ]
    });

    expect(view.control).toEqual({
      loading: false,
      submitting: false,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        }
      ]
    });
  });

  it('sets submitting when ensure begins', () => {
    const view = {
      control: {
        loading: false,
        submitting: false,
        error: 'old',
        farms: []
      }
    };
    presenter.setView(view);

    presenter.beginEnsure();

    expect(view.control.submitting).toBe(true);
    expect(view.control.error).toBeNull();
  });

  it('navigates to work screen on ensure success without flash when plan existed', () => {
    presenter.setView({
      control: { loading: false, submitting: true, error: null, farms: [] }
    });

    presenter.onSuccess({ planId: 42, created: false });

    expect(flashShow).not.toHaveBeenCalled();
    expect(navigate).toHaveBeenCalledWith(['/plans', 42, 'work']);
  });

  it('shows flash and navigates when a new plan was created', () => {
    presenter.setView({
      control: { loading: false, submitting: true, error: null, farms: [] }
    });

    presenter.onSuccess({ planId: 99, created: true });

    expect(flashShow).toHaveBeenCalledWith({
      type: 'success',
      text: 'Plan created'
    });
    expect(navigate).toHaveBeenCalledWith(['/plans', 99, 'work']);
  });
});
