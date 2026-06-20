import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { InteractionRuleDetailComponent } from './interaction-rule-detail.component';
import { LoadInteractionRuleDetailUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-detail.usecase';
import { DeleteInteractionRuleUseCase } from '../../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { InteractionRuleDetailPresenter } from '../../../usecase/interaction-rules/interaction-rule-detail.providers';

describe('InteractionRuleDetailComponent', () => {
  let fixture: ComponentFixture<InteractionRuleDetailComponent>;
  let component: InteractionRuleDetailComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InteractionRuleDetailComponent, TranslateModule.forRoot()],
      providers: [
        InteractionRuleDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LoadInteractionRuleDetailUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteInteractionRuleUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(InteractionRuleDetailComponent, {
        set: {
          providers: [
            { provide: LoadInteractionRuleDetailUseCase, useValue: { execute: vi.fn() } },
            { provide: DeleteInteractionRuleUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(InteractionRuleDetailComponent);
    component = fixture.componentInstance;
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: { true: 'Yes', false: 'No' },
      interaction_rules: {
        show: {
          rule_type: 'Rule type',
          direction: 'Directional'
        },
        form: {
          rule_type_codes: {
            continuous_cultivation: 'Continuous cultivation'
          }
        }
      }
    });
    translate.use('en');
  });

  it('renders translated rule type label via ruleTypeLabel', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      rule: {
        id: 1,
        rule_type: 'continuous_cultivation',
        source_group: 'Solanaceae',
        target_group: 'Brassicaceae',
        impact_ratio: 0.8,
        is_directional: true,
        description: null,
        region: null,
        is_reference: false
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Continuous cultivation');
    expect(el.textContent).not.toContain('continuous_cultivation');
  });

  it('renders translated direction label for is_directional', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      rule: {
        id: 1,
        rule_type: 'continuous_cultivation',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 1,
        is_directional: false,
        description: null,
        region: null,
        is_reference: false
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('No');
    expect(el.textContent).not.toContain('common.false');
  });
});
