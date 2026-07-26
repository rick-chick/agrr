import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, describe, it, expect, beforeEach } from 'vitest';
import { AppSeoMetaService } from './app-seo-meta.service';

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
          contact: {
            title: 'お問い合わせ',
            description: 'Contact説明'
          }
        }
      },
      true
    );
    translate.use('ja');
  });

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...window.location, pathname: '/' }
    });
  });

  it('sets document title and description from default meta keys on home', () => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...window.location, pathname: '/' }
    });
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('uses route-specific pages.* keys on /about', () => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...window.location, pathname: '/about' }
    });
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRRについて');
    expect(meta.getTag('name="description"')?.content).toBe('About説明');
    expect(meta.getTag('property="og:title"')?.content).toBe('AGRRについて');
    expect(meta.getTag('property="og:description"')?.content).toBe('About説明');
  });

  it('falls back to meta.default on unknown routes', () => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...window.location, pathname: '/farms' }
    });
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });
});
