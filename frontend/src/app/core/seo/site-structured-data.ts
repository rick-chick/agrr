/** Matches `id` on the static JSON-LD script in `index.html` (prerender / no-JS crawlers). */
export const SITE_STRUCTURED_DATA_SCRIPT_ID = 'site-structured-data';

export type SiteStructuredDataInput = {
  baseUrl: string;
  siteTitle: string;
  siteDescription: string;
};

export type ContactFaqItem = {
  question: string;
  answer: string;
};

type StructuredDataNode = Record<string, unknown>;

const ORGANIZATION_ID_SUFFIX = '#organization';
const WEBSITE_ID_SUFFIX = '#website';

export function buildSiteStructuredDataGraph(
  input: SiteStructuredDataInput
): StructuredDataNode[] {
  const baseUrl = input.baseUrl.replace(/\/$/, '');
  const organizationId = `${baseUrl}/${ORGANIZATION_ID_SUFFIX}`;
  const websiteId = `${baseUrl}/${WEBSITE_ID_SUFFIX}`;

  return [
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
}

export function buildContactFaqPageNode(
  faqItems: ContactFaqItem[]
): StructuredDataNode | null {
  if (!faqItems.length) {
    return null;
  }

  return {
    '@type': 'FAQPage',
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

export function buildSiteStructuredDataGraphWithOptionalFaq(
  input: SiteStructuredDataInput,
  faqItems?: ContactFaqItem[]
): StructuredDataNode[] {
  const graph = buildSiteStructuredDataGraph(input);
  const faqNode = faqItems?.length ? buildContactFaqPageNode(faqItems) : null;
  if (faqNode) {
    graph.push(faqNode);
  }
  return graph;
}

export function buildSiteStructuredDataDocument(input: SiteStructuredDataInput): string {
  return JSON.stringify({
    '@context': 'https://schema.org',
    '@graph': buildSiteStructuredDataGraph(input)
  });
}

export function buildSiteStructuredDataDocumentWithOptionalFaq(
  input: SiteStructuredDataInput,
  faqItems?: ContactFaqItem[]
): string {
  return JSON.stringify({
    '@context': 'https://schema.org',
    '@graph': buildSiteStructuredDataGraphWithOptionalFaq(input, faqItems)
  });
}
