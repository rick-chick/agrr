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

  it('translates flash.farms.deleted:name from API', () => {
    expect(translateServerToastMessage('flash.farms.deleted:North Field', instant)).toBe(
      'North Field was deleted.'
    );
  });

  it('translates bare undo toast keys', () => {
    expect(translateServerToastMessage('pests.undo.toast', instant)).toBe(
      '%{name} was deleted. You can undo this action.'
    );
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
