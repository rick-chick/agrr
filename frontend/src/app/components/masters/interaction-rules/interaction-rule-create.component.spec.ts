import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, ActivatedRoute, convertToParamMap } from '@angular/router';
import { RouterTestingModule } from '@angular/router/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of } from 'rxjs';

import { InteractionRuleCreateComponent } from './interaction-rule-create.component';
import { InteractionRuleCreatePresenter } from '../../../usecase/interaction-rules/interaction-rule-create.providers';
import { CreateInteractionRuleUseCase } from '../../../usecase/interaction-rules/create-interaction-rule.usecase';
import { CREATE_INTERACTION_RULE_OUTPUT_PORT } from '../../../usecase/interaction-rules/create-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from '../../../usecase/interaction-rules/interaction-rule-gateway';
import { AuthService } from '../../../services/auth.service';

describe('InteractionRuleCreateComponent', () => {
  let component: InteractionRuleCreateComponent;
  let fixture: ComponentFixture<InteractionRuleCreateComponent>;
  let mockRouter: any;
  let mockPresenter: any;
  let mockCreateUseCase: any;
  let mockAuthService: any;
  let currentUser: { admin: boolean; region?: string | null } | null;

  beforeEach(async () => {
    mockRouter = {
      navigate: vi.fn(),
      events: { subscribe: vi.fn() },
      routerState: {},
      url: '',
      createUrlTree: vi.fn(),
      serializeUrl: vi.fn()
    };

    mockPresenter = {
      setView: vi.fn()
    };

    mockCreateUseCase = {
      execute: vi.fn()
    };

    currentUser = null;
    mockAuthService = {
      user: vi.fn(() => currentUser)
    };
    const mockActivatedRoute = {
      snapshot: { paramMap: convertToParamMap({}) },
      params: of({}),
      queryParams: of({})
    };

    await TestBed.configureTestingModule({
      imports: [InteractionRuleCreateComponent, TranslateModule.forRoot(), RouterTestingModule],
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        { provide: ActivatedRoute, useValue: mockActivatedRoute }
      ]
    })
      .overrideComponent(InteractionRuleCreateComponent, {
        set: {
          providers: [
            { provide: InteractionRuleCreatePresenter, useValue: mockPresenter },
            { provide: CreateInteractionRuleUseCase, useValue: mockCreateUseCase },
            { provide: CREATE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleCreatePresenter },
            { provide: INTERACTION_RULE_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(InteractionRuleCreateComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should implement View interface control getter/setter', () => {
    const testState = {
      saving: true,
      error: 'Test error',
      pendingErrorFlash: null,
      formData: {
        rule_type: 'continuous_cultivation',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 0.5,
        is_directional: false,
        description: null,
        region: 'jp'
      }
    };

    component.control = testState;
    expect(component.control).toEqual(testState);
  });

  it('should set view on presenter in ngOnInit', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('should override region with user region when not admin', () => {
    currentUser = { admin: false, region: 'jp' };
    component.control = {
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: {
        rule_type: 'continuous_cultivation',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 0.5,
        is_directional: false,
        description: null,
        region: 'us'
      },
    };

    component.createInteractionRule();

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        region: 'jp'
      })
    );
  });

  it('should use form region when admin', () => {
    currentUser = { admin: true, region: 'jp' };
    component.control = {
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: {
        rule_type: 'continuous_cultivation',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 0.5,
        is_directional: false,
        description: null,
        region: 'us'
      },
    };

    component.createInteractionRule();

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        region: 'us'
      })
    );
  });

  it('shows master context header and omits back link from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        interaction_rules: {
          index: { title: 'Rotations' },
          new: { title: 'Create New Rule' }
        }
      },
      true
    );
    translate.use('en');

    expect(component.contextCrumbs[0].routerLink).toEqual(['/interaction_rules']);
    expect(component.contextCrumbs[1].labelKey).toBe('interaction_rules.new.title');
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
