import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
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
            og_description: 'OG説明',
            og_image_alt: 'AGRR 農業計画支援システムの OGP 画像'
          }
        }
      },
      true
    );
    translate.use('ja');
    Object.defineProperty(window, 'location', {
      value: { origin: 'https://agrr.net', pathname: '/' },
      writable: true,
      configurable: true
    });
  });

  it('sets document title and description from default meta keys', () => {
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('sets default og:image, twitter:image, image alt, and summary_large_image card', () => {
    service.refreshDefaultMeta();
    expect(meta.getTag('property="og:image"')?.content).toBe('https://agrr.net/og-default.png');
    expect(meta.getTag('name="twitter:image"')?.content).toBe('https://agrr.net/og-default.png');
    expect(meta.getTag('name="twitter:image:alt"')?.content).toBe(
      'AGRR 農業計画支援システムの OGP 画像'
    );
    expect(meta.getTag('name="twitter:card"')?.content).toBe('summary_large_image');
  });

  it('does not set og:image when window origin is unavailable', () => {
    Object.defineProperty(window, 'location', {
      value: { origin: '', pathname: '/' },
      writable: true,
      configurable: true
    });
    service.refreshDefaultMeta();
    expect(meta.getTag('property="og:image"')).toBeNull();
    expect(meta.getTag('name="twitter:image"')).toBeNull();
  });
});
