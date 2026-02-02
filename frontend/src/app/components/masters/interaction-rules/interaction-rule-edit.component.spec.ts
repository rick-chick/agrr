import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { InteractionRuleEditComponent } from './interaction-rule-edit.component';
import { AuthService } from '../../../services/auth.service';
import { InteractionRuleEditPresenter } from '../../../adapters/interaction-rules/interaction-rule-edit.presenter';
import { LoadInteractionRuleForEditUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-for-edit.usecase';
import { UpdateInteractionRuleUseCase } from '../../../usecase/interaction-rules/update-interaction-rule.usecase';

const initialFormData = {
  rule_type: 'rule',
  source_group: 'source',
  target_group: 'target',
  impact_ratio: 0.5,
  is_directional: false,
  description: null,
  region: null
};

describe('InteractionRuleEditComponent', () => {
  let component: InteractionRuleEditComponent;
  let fixture: ComponentFixture<InteractionRuleEditComponent>;
  let mockActivatedRoute: any;
  let mockRouter: any;
  let mockLoadUseCase: any;
  let mockUpdateUseCase: any;
  let mockPresenter: any;
  let mockAuthService: any;
  let mockTranslateService: any;

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: () => '1'
        }
      }
    };
    mockRouter = {
      navigate: vi.fn(),
      events: of(),
      createUrlTree: vi.fn(() => ({})),
      serializeUrl: vi.fn(() => '')
    };
    mockLoadUseCase = { execute: vi.fn() };
    mockUpdateUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockAuthService = { user: vi.fn(() => ({ admin: true })) };
    // Use real TranslateService with simple in-test translations

    await TestBed.configureTestingModule({
      imports: [
        InteractionRuleEditComponent,
        TranslateModule.forRoot({ fallbackLang: 'en' })
      ],
      providers: [
        // Provide route and router at module level; component-level providers
        // (defined in the component) will be overridden below.
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: Router, useValue: mockRouter }
      ]
    })
      .overrideComponent(InteractionRuleEditComponent, {
        set: {
          providers: [
            { provide: LoadInteractionRuleForEditUseCase, useValue: mockLoadUseCase },
            { provide: UpdateInteractionRuleUseCase, useValue: mockUpdateUseCase },
            { provide: InteractionRuleEditPresenter, useValue: mockPresenter },
            { provide: AuthService, useValue: mockAuthService }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(InteractionRuleEditComponent);
    component = fixture.componentInstance;

    // Configure TranslateService with minimal translations for template pipes
    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.setTranslation('en', {
      'interaction_rules.edit.title': 'Interaction Rule Edit',
      'common.loading': 'Loading...',
      'interaction_rules.form.rule_type_label': 'Rule Type',
      'interaction_rules.form.source_group_label': 'Source Group',
      'interaction_rules.form.target_group_label': 'Target Group',
      'interaction_rules.form.impact_ratio_label': 'Impact Ratio',
      'interaction_rules.form.is_directional_label': 'Is Directional',
      'interaction_rules.form.description_label': 'Description',
      'interaction_rules.form.submit_update': 'Update',
      'common.back': 'Back'
    });
    translate.use('en');
  });

  it('loads interaction rule on init', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ interactionRuleId: 1 });
  });

  it('sets error when interaction rule id is missing', () => {
    mockActivatedRoute.snapshot.paramMap.get = () => null;
    component.ngOnInit();
    expect(component.control.error).toBe('Invalid interaction rule id.');
  });

  it('uses form region for admin submit', () => {
    mockAuthService.user.mockReturnValue({ admin: true });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: { ...initialFormData, region: 'jp' }
    };

    component.updateInteractionRule();

    const args = mockUpdateUseCase.execute.mock.calls[0][0];
    expect(args).toEqual(expect.objectContaining({ interactionRuleId: 1, region: 'jp' }));
    expect(typeof args.onSuccess).toBe('function');
  });

  it('uses user region for non-admin submit', () => {
    mockAuthService.user.mockReturnValue({ admin: false, region: 'us' });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: { ...initialFormData, region: 'jp' }
    };

    component.updateInteractionRule();

    const args = mockUpdateUseCase.execute.mock.calls[0][0];
    expect(args).toEqual(expect.objectContaining({ interactionRuleId: 1, region: 'us' }));
  });

  it('hides region select for non-admin users', () => {
    mockAuthService.user.mockReturnValue({ admin: false, region: 'us' });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: { ...initialFormData, region: 'jp' }
    };

    fixture.detectChanges();

    const regionSelect = fixture.nativeElement.querySelector('app-region-select');
    expect(regionSelect).toBeNull();
  });
});
