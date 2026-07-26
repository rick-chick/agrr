import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
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
    window.history.replaceState({}, '', '/');
  });

  it('sets document title and description from default meta keys on home', () => {
    window.history.replaceState({}, '', '/');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('sets route-specific title and description for /about', () => {
    window.history.replaceState({}, '', '/about');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRRについて');
    expect(meta.getTag('name="description"')?.content).toBe('About説明');
    expect(meta.getTag('property="og:title"')?.content).toBe('AGRRについて');
    expect(meta.getTag('property="og:description"')?.content).toBe('About説明');
  });

  it('falls back to meta.default for undefined routes', () => {
    window.history.replaceState({}, '', '/plans');
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });
});
