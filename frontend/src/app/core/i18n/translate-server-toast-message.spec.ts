import { describe, expect, it } from 'vitest';
import {
  parseServerToastMessage,
  translateServerToastMessage
} from './translate-server-toast-message';

describe('parseServerToastMessage', () => {
  it('parses key:param as name interpolation', () => {
    expect(parseServerToastMessage('flash.farms.deleted:North Field')).toEqual({
      key: 'flash.farms.deleted',
      params: { name: 'North Field' }
    });
  });

  it('parses bare i18n key without params', () => {
    expect(parseServerToastMessage('pests.undo.toast')).toEqual({
      key: 'pests.undo.toast',
      params: {}
    });
  });

  it('returns null for human-readable literals', () => {
    expect(parseServerToastMessage('プラン Foo を削除しました')).toBeNull();
    expect(parseServerToastMessage('')).toBeNull();
  });
});

describe('translateServerToastMessage', () => {
  const catalog: Record<string, string> = {
    'flash.farms.deleted': '%{name} was deleted.',
    'farms.validation.required_fields':
      'Farm name, region, latitude, and longitude are required.',
    'pests.undo.toast': '%{name} was deleted. You can undo this action.',
    'plans.undo.toast': '%{name} was deleted. You can undo this action.'
  };

  const instant = (key: string, params?: Record<string, string>): string => {
    const template = catalog[key] ?? key;
    if (!params) return template;
    return Object.entries(params).reduce(
      (text, [k, v]) => text.replaceAll(`%{${k}}`, v).replaceAll(`{{${k}}}`, v),
      template
    );
  };

  it('translates farms.validation.required_fields from API errors', () => {
    expect(translateServerToastMessage('farms.validation.required_fields', instant)).toBe(
      'Farm name, region, latitude, and longitude are required.'
    );
  });

  it('translates flash.farms.deleted:name from API', () => {
    expect(translateServerToastMessage('flash.farms.deleted:North Field', instant)).toBe(
      'North Field was deleted.'
    );
  });

  it('translates bare undo toast keys without fallback as template', () => {
    expect(translateServerToastMessage('pests.undo.toast', instant)).toBe(
      '%{name} was deleted. You can undo this action.'
    );
  });

  it('interpolates bare undo toast keys when resource name is provided', () => {
    expect(
      translateServerToastMessage('pests.undo.toast', instant, { name: 'Aphid' })
    ).toBe('Aphid was deleted. You can undo this action.');
  });

  it('interpolates server %{name} templates when resource name is provided', () => {
    const hindiTemplate =
      '%{name} हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।';
    expect(
      translateServerToastMessage(hindiTemplate, instant, { name: 'Tomato' })
    ).toBe('Tomato हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।');
  });

  it('interpolates ngx {{name}} catalog when instant leaves placeholders', () => {
    const ngxInstant = (key: string, _params?: Record<string, string>): string => {
      if (key === 'plans.undo.toast') {
        return '{{name}} हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।';
      }
      return key;
    };
    expect(
      translateServerToastMessage('plans.undo.toast', ngxInstant, { name: 'Plan A' })
    ).toBe('Plan A हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।');
  });

  it('translates plans.undo.toast:name', () => {
    expect(translateServerToastMessage('plans.undo.toast:Plan A', instant)).toBe(
      'Plan A was deleted. You can undo this action.'
    );
  });

  it('returns literals unchanged when not in catalog', () => {
    expect(translateServerToastMessage('プラン Foo を削除しました', instant)).toBe(
      'プラン Foo を削除しました'
    );
  });
});
