import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { InteractionRuleDetailComponent } from './interaction-rule-detail.component';
import { LoadInteractionRuleDetailUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-detail.usecase';
import { DeleteInteractionRuleUseCase } from '../../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { InteractionRuleDetailPresenter } from '../../../usecase/interaction-rules/interaction-rule-detail.providers';

describe('InteractionRuleDetailComponent', () => {
  let fixture: ComponentFixture<InteractionRuleDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InteractionRuleDetailComponent, TranslateModule.forRoot()],
      providers: [
        InteractionRuleDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
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

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: {
        edit: 'Edit',
        back: 'Back',
        delete: 'Delete',
        true: 'Yes',
        false: 'No'
      },
      interaction_rules: {
        show: {
          rule_type: 'Rule type',
          source_group: 'Source',
          target_group: 'Target',
          impact_ratio: 'Impact',
          direction: 'Direction'
        },
        form: {
          rule_type_codes: {
            continuous_cultivation: 'Continuous cultivation'
          }
        }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(InteractionRuleDetailComponent);
  });

  it('shows human-readable rule type instead of raw code', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      rule: {
        id: 1,
        rule_type: 'continuous_cultivation',
        source_group: 'Solanaceae',
        target_group: 'Brassica',
        impact_ratio: 0.8,
        is_directional: true,
        region: null,
        is_reference: false
      }
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Continuous cultivation');
    expect(text).not.toContain('continuous_cultivation');
    expect(text).not.toContain('interaction_rules.form.rule_type_codes');
  });

  it('uses show.direction label with translated boolean values', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      rule: {
        id: 1,
        rule_type: 'continuous_cultivation',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 1,
        is_directional: false,
        region: null,
        is_reference: false
      }
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Direction');
    expect(text).toContain('No');
    expect(text).not.toContain('interaction_rules.show.is_directional');
  });
});
