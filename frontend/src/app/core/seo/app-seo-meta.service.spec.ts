import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { AppSeoMetaService } from './app-seo-meta.service';

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
});
