import { describe, expect, it } from 'vitest';

import { buildSiteStructuredDataGraph } from './site-structured-data';

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
