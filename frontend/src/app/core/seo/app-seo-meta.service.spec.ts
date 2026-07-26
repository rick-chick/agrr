import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
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
  });

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: window.location
    });
  });

  it('sets document title and description from default meta keys', () => {
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
