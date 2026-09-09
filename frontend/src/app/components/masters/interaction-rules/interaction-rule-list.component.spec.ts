import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { InteractionRuleListComponent } from './interaction-rule-list.component';
import { InteractionRuleListPresenter } from '../../../usecase/interaction-rules/interaction-rule-list.providers';
import { LoadInteractionRuleListUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-list.usecase';
import { DeleteInteractionRuleUseCase } from '../../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';

const rule: InteractionRule = {
  id: 1,
  rule_type: 'continuous_cultivation',
  source_group: 'Tomato',
  target_group: 'Potato',
  impact_ratio: 0.8,
  is_directional: true,
  region: null,
  is_reference: false
};

describe('InteractionRuleListComponent uniform card rows', () => {
  let fixture: ComponentFixture<InteractionRuleListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InteractionRuleListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadInteractionRuleListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteInteractionRuleUseCase, useValue: { execute: vi.fn() } },
        { provide: InteractionRuleListPresenter, useValue: { setView: vi.fn() } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(InteractionRuleListComponent, { set: { providers: [] } })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      interaction_rules: {
        form: { rule_type_codes: { continuous_cultivation: 'Continuous cultivation' } }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(InteractionRuleListComponent);
    fixture.detectChanges();
  });

  it('uses uniform card layout with single-line title and meta rows', () => {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      errorIsWarmup: false,
      rules: [rule],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const el = fixture.nativeElement;
    const body = el.querySelector('.item-card__body') as HTMLElement;
    const title = el.querySelector('.item-card__title--single-line') as HTMLElement;
    const meta = el.querySelector('.interaction-rule-list__meta.item-card__meta--single-line') as HTMLElement;

    expect(body.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(title.textContent?.trim()).toBe('Tomato → Potato');
    expect(meta).toBeTruthy();
    expect(meta.textContent).toContain('Continuous cultivation');
    expect(meta.textContent).toContain('0.8');
  });

  it('sets title attribute on card body link for full rule text', () => {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      errorIsWarmup: false,
      rules: [rule],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const bodyLink = fixture.nativeElement.querySelector('.interaction-rule-list__card-body') as HTMLAnchorElement;
    expect(bodyLink.getAttribute('title')).toBe('Tomato → Potato');
  });
});
