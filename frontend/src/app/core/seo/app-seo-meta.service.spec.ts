import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { AppSeoMetaService, buildSelfCanonicalUrl } from './app-seo-meta.service';

const TEST_ORIGIN = 'http://localhost';

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
      providers: [AppSeoMetaService]
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
          }
        }
      },
      true
    );
    translate.use('ja');
  });

  afterEach(() => {
    setWindowPath('/');
  });

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

  it('applyNotFoundMeta sets robots noindex', () => {
    service.applyNotFoundMeta();
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');
  });

  it('refreshDefaultMeta removes robots noindex after not-found', () => {
    service.applyNotFoundMeta();
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');

    setWindowPath('/about');
    service.refreshDefaultMeta();

    expect(meta.getTag('name="robots"')).toBeNull();
  });

  it('refreshDefaultMeta does not set robots noindex on public routes', () => {
    setWindowPath('/about');
    service.refreshDefaultMeta();
    expect(meta.getTag('name="robots"')).toBeNull();
  });
});
