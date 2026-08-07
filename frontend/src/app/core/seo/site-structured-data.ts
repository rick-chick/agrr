/** Matches `id` on the static JSON-LD script in `index.html` (prerender / no-JS crawlers). */
export const SITE_STRUCTURED_DATA_SCRIPT_ID = 'site-structured-data';

export type ContactFaqItem = {
  question: string;
  answer: string;
};

export type SiteStructuredDataInput = {
  baseUrl: string;
  siteTitle: string;
  siteDescription: string;
  pageUrl?: string;
  faqItems?: ContactFaqItem[];
};

type StructuredDataNode = Record<string, unknown>;

const ORGANIZATION_ID_SUFFIX = '#organization';
const WEBSITE_ID_SUFFIX = '#website';
const FAQ_ID_SUFFIX = '#faq';

export function buildContactFaqPageStructuredDataNode(
  faqItems: ContactFaqItem[],
  pageUrl: string
): StructuredDataNode {
  return {
    '@type': 'FAQPage',
    '@id': `${pageUrl.replace(/\/$/, '')}${FAQ_ID_SUFFIX}`,
    mainEntity: faqItems.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.answer
      }
    }))
  };
}

export function buildSiteStructuredDataGraph(
  input: SiteStructuredDataInput
): StructuredDataNode[] {
  const baseUrl = input.baseUrl.replace(/\/$/, '');
  const organizationId = `${baseUrl}/${ORGANIZATION_ID_SUFFIX}`;
  const websiteId = `${baseUrl}/${WEBSITE_ID_SUFFIX}`;

  const graph: StructuredDataNode[] = [
    {
      '@type': 'Organization',
      '@id': organizationId,
      name: 'AGRR',
      url: `${baseUrl}/`,
      email: 'support@agrr.net',
      address: {
        '@type': 'PostalAddress',
        addressCountry: 'JP'
      },
      sameAs: ['https://github.com/rick-chick/agrr']
    },
    {
      '@type': 'WebSite',
      '@id': websiteId,
      name: 'AGRR',
      alternateName: input.siteTitle,
      url: `${baseUrl}/`,
      description: input.siteDescription,
      publisher: { '@id': organizationId }
    },
    {
      '@type': 'SoftwareApplication',
      name: 'AGRR',
      alternateName: input.siteTitle,
      applicationCategory: 'BusinessApplication',
      operatingSystem: 'Web',
      url: `${baseUrl}/`,
      description: input.siteDescription
    }
  ];

  if (input.pageUrl && input.faqItems?.length) {
    graph.push(buildContactFaqPageStructuredDataNode(input.faqItems, input.pageUrl));
  }

  return graph;
}

export function buildSiteStructuredDataDocument(input: SiteStructuredDataInput): string {
  return JSON.stringify({
    '@context': 'https://schema.org',
    '@graph': buildSiteStructuredDataGraph(input)
  });
}
