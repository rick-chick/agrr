import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { AppSeoMetaService } from './app-seo-meta.service';
import { buildSelfCanonicalUrl } from './seo-url';
import { SITE_STRUCTURED_DATA_SCRIPT_ID } from './site-structured-data';

const TEST_ORIGIN = 'http://localhost';

function canonicalHref(): string | null {
  return document.head.querySelector('link[rel="canonical"]')?.getAttribute('href') ?? null;
}

function setWindowPath(pathname: string): void {
  Object.defineProperty(window, 'location', {
    value: {
      pathname,
      href: `${TEST_ORIGIN}${pathname}`,
      origin: TEST_ORIGIN
    },
    writable: true,
    configurable: true
  });
}

describe('AppSeoMetaService', () => {
  let service: AppSeoMetaService;
  let title: Title;
  let meta: Meta;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [
        AppSeoMetaService,
        { provide: Router, useValue: { url: '/' } },
      ],
    });
    service = TestBed.inject(AppSeoMetaService);
    title = TestBed.inject(Title);
    meta = TestBed.inject(Meta);
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        meta: {
          default: {
            title: 'AGRR タイトル',
            description: '説明文',
            keywords: '農業,計画',
            og_description: 'OG説明',
            og_image_alt: 'AGRR 農業計画支援システムの OGP 画像'
          }
        },
        pages: {
          about: {
            title: 'AGRRについて',
            description: 'About説明'
          },
          public_plans_new: {
            title: '無料作付け計画を作成',
            description: 'Public plans説明'
          },
          public_plans_results: {
            title: '{{planLabel}} — 作付け計画',
            description: '{{cropLabels}}（{{planYear}}年・{{totalArea}}㎡）',
            og_description: '{{planLabel}}の栽培スケジュール（{{cropLabels}}）'
          }
        }
      },
      true
    );
    translate.use('ja');
  });

  afterEach(() => {
    setWindowPath('/');
    document.head.querySelector('link[rel="canonical"]')?.remove();
    document.head
      .querySelectorAll('script[type="application/ld+json"]')
      .forEach((node) => node.remove());
  });

  function insertStaticJsonLdScript(): HTMLScriptElement {
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.id = SITE_STRUCTURED_DATA_SCRIPT_ID;
    script.text = JSON.stringify({
      '@context': 'https://schema.org',
      '@graph': [{ '@type': 'Organization', name: 'AGRR' }]
    });
    document.head.appendChild(script);
    return script;
  }

  it('sets document title and description from default meta keys on home', () => {
    setWindowPath('/');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('sets route-specific title and description for /about', () => {
    setWindowPath('/about');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRRについて');
    expect(meta.getTag('name="description"')?.content).toBe('About説明');
    expect(meta.getTag('property="og:title"')?.content).toBe('AGRRについて');
    expect(meta.getTag('property="og:description"')?.content).toBe('About説明');
  });

  it('sets route-specific title and description for /public-plans/new', () => {
    setWindowPath('/public-plans/new');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('無料作付け計画を作成');
    expect(meta.getTag('name="description"')?.content).toBe('Public plans説明');
  });

  it('falls back to meta.default for undefined routes', () => {
    setWindowPath('/plans');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('uses router URL and production origin when window is unavailable (SSR prerender)', () => {
    const router = TestBed.inject(Router);
    Object.defineProperty(router, 'url', { value: '/about', configurable: true });
    const savedWindow = globalThis.window;
    Reflect.deleteProperty(globalThis, 'window');

    try {
      service.refreshDefaultMeta();

      expect(title.getTitle()).toBe('AGRRについて');
      expect(meta.getTag('property="og:url"')?.content).toBe('https://agrr.net/about');
      expect(canonicalHref()).toBe('https://agrr.net/about');
      expect(meta.getTag('property="og:image"')?.content).toBe('https://agrr.net/og-default.png');
    } finally {
      globalThis.window = savedWindow;
    }
  });

  it('skips JSON-LD injection when document is unavailable (SSR/prerender)', () => {
    setWindowPath('/');
    const scriptsBefore = document.head.querySelectorAll('script[type="application/ld+json"]').length;
    const doc = globalThis.document;
    Object.defineProperty(globalThis, 'document', { value: undefined, configurable: true });
    Object.defineProperty(window, 'document', { value: undefined, configurable: true });
    try {
      (
        service as unknown as {
          refreshJsonLd: (siteTitle: string, siteDescription: string, keyPrefix: string) => void;
        }
      ).refreshJsonLd('AGRR タイトル', '説明文', 'meta.default');
    } finally {
      Object.defineProperty(globalThis, 'document', { value: doc, configurable: true });
      Object.defineProperty(window, 'document', { value: doc, configurable: true });
    }
    const scriptsAfter = document.head.querySelectorAll('script[type="application/ld+json"]').length;
    expect(scriptsAfter).toBe(scriptsBefore);
  });

  it('injects Organization JSON-LD on refreshDefaultMeta', () => {
    service.refreshDefaultMeta();
    const script = document.head.querySelector('script[type="application/ld+json"]');
    expect(script).not.toBeNull();
    const structured = JSON.parse(script?.textContent ?? '{}');
    const graph = structured['@graph'] as Array<Record<string, unknown>>;
    const organization = graph.find((node) => node['@type'] === 'Organization');
    expect(organization).toMatchObject({
      name: 'AGRR',
      email: 'support@agrr.net'
    });
  });

  it('updates static index.html JSON-LD in place without duplicating scripts', () => {
    const staticScript = insertStaticJsonLdScript();
    setWindowPath('/');

    service.refreshDefaultMeta();
    let scripts = document.head.querySelectorAll('script[type="application/ld+json"]');
    expect(scripts.length).toBe(1);
    expect(scripts[0]).toBe(staticScript);

    service.refreshDefaultMeta();
    scripts = document.head.querySelectorAll('script[type="application/ld+json"]');
    expect(scripts.length).toBe(1);
    expect(scripts[0]).toBe(staticScript);

    const structured = JSON.parse(staticScript.textContent ?? '{}');
    const website = (structured['@graph'] as Array<Record<string, unknown>>).find(
      (node) => node['@type'] === 'WebSite'
    );
    expect(website).toMatchObject({
      name: 'AGRR',
      description: 'OG説明'
    });
  });

  it('buildSelfCanonicalUrl strips query from pathname and joins origin', () => {
    expect(
      buildSelfCanonicalUrl('https://agrr.net', '/public-plans/results')
    ).toBe('https://agrr.net/public-plans/results');
    expect(buildSelfCanonicalUrl('', '/about')).toBe('');
  });

  it('sets default OGP image tags with absolute URL and large Twitter card', () => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        origin: 'https://agrr.net',
        pathname: '/entry-schedule'
      }
    });

    service.refreshDefaultMeta();

    expect(meta.getTag('property="og:image"')?.content).toBe('https://agrr.net/og-default.png');
    expect(meta.getTag('name="twitter:image"')?.content).toBe('https://agrr.net/og-default.png');
    expect(meta.getTag('name="twitter:image:alt"')?.content).toBe(
      'AGRR 農業計画支援システムの OGP 画像'
    );
    expect(meta.getTag('name="twitter:card"')?.content).toBe('summary_large_image');
  });

  it('sets robots noindex via applyNoIndexMeta', () => {
    service.applyNoIndexMeta();
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');
  });

  it('removes robots noindex via removeNoIndexMeta', () => {
    service.applyNoIndexMeta();
    service.removeNoIndexMeta();
    expect(meta.getTag('name="robots"')).toBeNull();
  });

  it('re-applies noindex after refreshDefaultMeta when noIndexActive', () => {
    service.applyNoIndexMeta();
    setWindowPath('/about');
    service.refreshDefaultMeta();
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');
    expect(title.getTitle()).toBe('AGRRについて');
  });

  it('does not set noindex on refreshDefaultMeta for normal routes', () => {
    setWindowPath('/about');
    service.refreshDefaultMeta();
    expect(meta.getTag('name="robots"')).toBeNull();
  });

  const samplePlanData: CultivationPlanData = {
    success: true,
    data: {
      id: 7,
      plan_year: 2026,
      plan_name: '関東',
      status: 'completed',
      total_area: 1200,
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      fields: [],
      crops: [{ id: 1, name: 'トマト', area_per_unit: 1, revenue_per_area: 10 }],
      cultivations: []
    },
    total_profit: 0,
    total_revenue: 0,
    total_cost: 0
  };

  it('refreshPublicPlanResultsMeta sets plan-specific OGP with planId in canonical URL', () => {
    setWindowPath('/public-plans/results');
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        origin: 'https://agrr.net',
        pathname: '/public-plans/results',
        href: 'https://agrr.net/public-plans/results?planId=7',
        search: '?planId=7'
      }
    });

    service.refreshPublicPlanResultsMeta(7, samplePlanData);

    expect(title.getTitle()).toBe('関東 — 作付け計画');
    expect(meta.getTag('property="og:title"')?.content).toBe('関東 — 作付け計画');
    expect(meta.getTag('property="og:description"')?.content).toBe(
      '関東の栽培スケジュール（トマト）'
    );
    expect(meta.getTag('property="og:url"')?.content).toBe(
      'https://agrr.net/public-plans/results?planId=7'
    );
    expect(canonicalHref()).toBe(
      'https://agrr.net/public-plans/results?planId=7'
    );
    expect(meta.getTag('property="og:image"')?.content).toBe('https://agrr.net/og-default.png');
  });

  it('refreshPublicPlanResultsMeta falls back to public_plans_new when plan data is null', () => {
    setWindowPath('/public-plans/results');
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        origin: 'https://agrr.net',
        pathname: '/public-plans/results',
        href: 'https://agrr.net/public-plans/results',
        search: ''
      }
    });

    service.refreshPublicPlanResultsMeta(null, null);

    expect(title.getTitle()).toBe('無料作付け計画を作成');
    expect(meta.getTag('property="og:url"')?.content).toBe('https://agrr.net/public-plans/results');
  });

  it('omits OGP image tags when origin is unavailable', () => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        origin: '',
        pathname: '/'
      }
    });

    service.refreshDefaultMeta();

    expect(meta.getTag('property="og:image"')).toBeNull();
    expect(meta.getTag('name="twitter:image"')).toBeNull();
    expect(meta.getTag('name="twitter:image:alt"')).toBeNull();
    expect(meta.getTag('name="twitter:card"')?.content).toBe('summary');
  });
});
