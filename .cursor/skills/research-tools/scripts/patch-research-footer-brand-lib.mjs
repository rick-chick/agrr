export const RESEARCH_FOOTER_OLD_HTML =
  '<a href="https://github.com/langchain-ai/open_deep_research" target="_blank" rel="noopener">OpenDeepResearch</a> ｜ <a href="https://agrr.net" target="_blank" rel="noopener">agrr.net</a>';

export const RESEARCH_FOOTER_NEW_HTML =
  '<a href="https://agrr.net/" target="_blank" rel="noopener">AGRR</a> ｜ <a href="https://github.com/langchain-ai/open_deep_research" target="_blank" rel="noopener">OpenDeepResearch</a>';

export const RESEARCH_FOOTER_OLD_ESCAPED =
  '\\\\\\"https://github.com/langchain-ai/open_deep_research\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">OpenDeepResearch</a> ｜ <a href=\\\\\\"https://agrr.net\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">agrr.net</a>';

export const RESEARCH_FOOTER_NEW_ESCAPED =
  '\\\\\\"https://agrr.net/\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">AGRR</a> ｜ <a href=\\\\\\"https://github.com/langchain-ai/open_deep_research\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">OpenDeepResearch</a>';

export function patchResearchFooterBrand(content) {
  if (!content.includes('OpenDeepResearch')) {
    return content;
  }
  return content
    .replaceAll(RESEARCH_FOOTER_OLD_HTML, RESEARCH_FOOTER_NEW_HTML)
    .replaceAll(RESEARCH_FOOTER_OLD_ESCAPED, RESEARCH_FOOTER_NEW_ESCAPED);
}
