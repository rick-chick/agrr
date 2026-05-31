import { describe, expect, it } from 'vitest';

import { AgrrTranslateParser } from './agrr-translate.parser';

describe('AgrrTranslateParser', () => {
  const parser = new AgrrTranslateParser();

  it('interpolates ngx {{name}} placeholders', () => {
    expect(parser.interpolate('{{name}} संपादित करें', { name: 'Tomato' })).toBe(
      'Tomato संपादित करें'
    );
  });

  it('interpolates Rails %{name} placeholders (legacy catalog / stale assets)', () => {
    expect(parser.interpolate('%{name} संपादित करें', { name: 'Tomato' })).toBe(
      'Tomato संपादित करें'
    );
  });

  it('applies ngx first then Rails for mixed remnants', () => {
    expect(parser.interpolate('{{name}} / %{name}', { name: 'A' })).toBe('A / A');
  });
});
