import { describe, it, expect } from 'vitest';
import ja from '../../../assets/i18n/ja.json';
import { resolveRouteSeoMeta } from './resolve-route-seo-meta';

describe('resolveRouteSeoMeta', () => {
  it('resolves home route meta from ja translations', () => {
    const meta = resolveRouteSeoMeta('/', ja);
    expect(meta.title).toBe(
      'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム'
    );
    expect(meta.description).toContain('agrr.net');
    expect(meta.canonicalUrl).toBe('https://agrr.net/');
    expect(meta.ogImageUrl).toBe('https://agrr.net/og-default.png');
  });

  it('resolves about route meta with self-referencing canonical', () => {
    const meta = resolveRouteSeoMeta('/about', ja);
    expect(meta.title).toBe('AGRRについて');
    expect(meta.description).toContain('農業作付け計画支援システム');
    expect(meta.canonicalUrl).toBe('https://agrr.net/about');
    expect(meta.ogImageUrl).toBe('https://agrr.net/og-default.png');
  });

  it('resolves public-plans/new route meta', () => {
    const meta = resolveRouteSeoMeta('/public-plans/new', ja);
    expect(meta.title).toBe('無料作付け計画を作成');
    expect(meta.canonicalUrl).toBe('https://agrr.net/public-plans/new');
  });

  it('resolves entry-schedule route og_description fallback', () => {
    const meta = resolveRouteSeoMeta('/entry-schedule', ja);
    expect(meta.title).toBe('作付け時期の目安');
    expect(meta.ogDescription).toBe('気象予測に基づく作物の播種・定植の目安時期を確認');
    expect(meta.canonicalUrl).toBe('https://agrr.net/entry-schedule');
  });
});
