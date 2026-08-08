import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const stylesCss = readFileSync(join(import.meta.dirname, 'styles.css'), 'utf8');

describe('styles.css dark theme (prefers-color-scheme)', () => {
  it('declares color-scheme on :root for OS theme integration', () => {
    const rootBlock = stylesCss.match(/:root\s*\{[^}]+\}/s)?.[0] ?? '';
    expect(rootBlock).toMatch(/color-scheme:\s*light\s+dark/);
  });

  it('defines prefers-color-scheme: dark token overrides', () => {
    expect(stylesCss).toMatch(/@media\s*\(\s*prefers-color-scheme:\s*dark\s*\)/);
    const darkBlock =
      stylesCss.match(
        /@media\s*\(\s*prefers-color-scheme:\s*dark\s*\)\s*\{[\s\S]*?\n\}/,
      )?.[0] ?? '';
    expect(darkBlock).toContain('--color-surface:');
    expect(darkBlock).toContain('--color-background:');
    expect(darkBlock).toContain('--color-text:');
    expect(darkBlock).toContain('--color-border:');
    expect(darkBlock).toContain('--color-error-muted-bg:');
    expect(darkBlock).toContain('--color-status-complete-bg:');
    expect(darkBlock).toContain('--focus-outline:');
  });

  it('uses darker surfaces than text in dark theme tokens', () => {
    const darkBlock =
      stylesCss.match(
        /@media\s*\(\s*prefers-color-scheme:\s*dark\s*\)\s*\{[\s\S]*?\n\}/,
      )?.[0] ?? '';
    const surface = darkBlock.match(/--color-surface:\s*(#[0-9a-f]{3,8})/i)?.[1];
    const background = darkBlock.match(/--color-background:\s*(#[0-9a-f]{3,8})/i)?.[1];
    const text = darkBlock.match(/--color-text:\s*(#[0-9a-f]{3,8})/i)?.[1];
    expect(surface).toBeTruthy();
    expect(background).toBeTruthy();
    expect(text).toBeTruthy();

    const luminance = (hex: string) => {
      const normalized = hex.replace('#', '');
      const channels = normalized.match(/.{2}/g)!.map((pair) => parseInt(pair, 16) / 255);
      return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
    };

    expect(luminance(text!)).toBeGreaterThan(luminance(surface!));
    expect(luminance(text!)).toBeGreaterThan(luminance(background!));
  });
});
