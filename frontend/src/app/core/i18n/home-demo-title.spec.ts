import { describe, expect, it } from 'vitest';
import { buildHomeDemoTitle } from './home-demo-title';

describe('buildHomeDemoTitle', () => {
  it('joins schedule, separator, and preview', () => {
    const title = buildHomeDemoTitle({
      instant: (key: string, params?: Record<string, string>) => {
        if (key === 'home.index.demo.title' && params) {
          return `${params['schedule']}${params['separator']}${params['preview']}`;
        }
        if (key === 'home.index.demo.schedule') return 'Schedule';
        if (key === 'home.index.demo.preview') return 'Preview';
        if (key === 'home.index.demo.separator') return ' · ';
        return key;
      }
    });
    expect(title).toBe('Schedule · Preview');
  });
});
