import { describe, expect, it } from 'vitest';

import {
  buildContactFaqPageNode,
  buildSiteStructuredDataGraph,
  buildSiteStructuredDataGraphWithOptionalFaq
} from './site-structured-data';

describe('buildSiteStructuredDataGraph', () => {
  it('includes Organization with email and sameAs', () => {
    const graph = buildSiteStructuredDataGraph({
      baseUrl: 'https://agrr.net',
      siteTitle: 'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      siteDescription: '気象データとAIを活用した農業作付け計画支援システム'
    });

    const organization = graph.find((node) => node['@type'] === 'Organization');
    expect(organization).toMatchObject({
      '@id': 'https://agrr.net/#organization',
      name: 'AGRR',
      url: 'https://agrr.net/',
      email: 'support@agrr.net',
      sameAs: ['https://github.com/rick-chick/agrr']
    });
  });

  it('links WebSite.publisher to Organization and unifies brand names', () => {
    const graph = buildSiteStructuredDataGraph({
      baseUrl: 'https://agrr.net',
      siteTitle: 'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      siteDescription: '気象データとAIを活用した農業作付け計画支援システム'
    });

    const website = graph.find((node) => node['@type'] === 'WebSite');
    const software = graph.find((node) => node['@type'] === 'SoftwareApplication');

    expect(website).toMatchObject({
      name: 'AGRR',
      alternateName:
        'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      publisher: { '@id': 'https://agrr.net/#organization' }
    });
    expect(software).toMatchObject({
      name: 'AGRR',
      alternateName:
        'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム'
    });
  });
});

describe('buildContactFaqPageNode', () => {
  it('builds FAQPage mainEntity from question/answer pairs', () => {
    const node = buildContactFaqPageNode([
      { question: 'ログインできない', answer: 'Google認証の設定をご確認ください' },
      { question: 'データが保存されない', answer: 'ブラウザのCookieが有効かご確認ください' }
    ]);

    expect(node).toMatchObject({
      '@type': 'FAQPage',
      mainEntity: [
        {
          '@type': 'Question',
          name: 'ログインできない',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'Google認証の設定をご確認ください'
          }
        },
        {
          '@type': 'Question',
          name: 'データが保存されない',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'ブラウザのCookieが有効かご確認ください'
          }
        }
      ]
    });
  });

  it('returns null when faq items are empty', () => {
    expect(buildContactFaqPageNode([])).toBeNull();
  });
});

describe('buildSiteStructuredDataGraphWithOptionalFaq', () => {
  it('appends FAQPage node when faq items are provided', () => {
    const graph = buildSiteStructuredDataGraphWithOptionalFaq(
      {
        baseUrl: 'https://agrr.net',
        siteTitle: 'AGRR タイトル',
        siteDescription: '説明文'
      },
      [{ question: 'Q1', answer: 'A1' }]
    );

    expect(graph.some((node) => node['@type'] === 'FAQPage')).toBe(true);
    expect(graph).toHaveLength(4);
  });
});
