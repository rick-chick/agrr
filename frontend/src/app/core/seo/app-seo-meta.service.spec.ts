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
            og_description: 'OG説明'
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

  it('buildSelfCanonicalUrl strips query from pathname and joins origin', () => {
    expect(
      buildSelfCanonicalUrl('https://agrr.net', '/public-plans/results')
    ).toBe('https://agrr.net/public-plans/results');
    expect(buildSelfCanonicalUrl('', '/about')).toBe('');
  });
});
