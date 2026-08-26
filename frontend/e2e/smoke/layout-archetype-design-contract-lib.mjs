/**
 * jsdom wrapper for design contract evaluation (unit tests).
 */

import { evaluateArchetypeDesignContract, maxActionButtonRowsForViewport, countVisibleMatches } from './layout-archetype-design-contract-browser-eval.mjs';

export { maxActionButtonRowsForViewport, countVisibleMatches };

/**
 * @param {object} input
 * @param {string} input.html
 * @param {string} input.hostSelector
 * @param {number} input.viewportWidth
 * @param {import('./layout-archetype-design-contracts.mjs').LayoutArchetypeDesignContract} input.contract
 * @param {string} [input.conformanceLevel]
 */
export function checkContentBlockLayout({ html, hostSelector, viewportWidth, contract, conformanceLevel = 'L0' }) {
  return import('jsdom').then(({ JSDOM }) => {
    const dom = new JSDOM(`<!DOCTYPE html><html><body>${html}</body></html>`, {
      pretendToBeVisual: true,
    });
    dom.window.innerWidth = viewportWidth;
    dom.window.innerHeight = 720;
    const previousDocument = globalThis.document;
    const previousInnerWidth = globalThis.innerWidth;
    globalThis.document = dom.window.document;
    globalThis.innerWidth = viewportWidth;
    Object.defineProperty(dom.window.HTMLElement.prototype, 'getBoundingClientRect', {
      configurable: true,
      value: function getBoundingClientRect() {
        const width =
          Number(this.getAttribute('data-width')) || Number.parseFloat(this.style.width) || 0;
        const height =
          Number(this.getAttribute('data-height')) || Number.parseFloat(this.style.height) || 32;
        const left = Number(this.getAttribute('data-left')) || 0;
        const top = Number(this.getAttribute('data-top')) || 0;
        return {
          top,
          left,
          right: left + width,
          bottom: top + height,
          width,
          height,
          x: left,
          y: top,
          toJSON() {
            return this;
          },
        };
      },
    });

    try {
      return evaluateArchetypeDesignContract({ hostSelector, contract, conformanceLevel });
    } finally {
      if (previousDocument === undefined) {
        delete globalThis.document;
      } else {
        globalThis.document = previousDocument;
      }
      if (previousInnerWidth === undefined) {
        delete globalThis.innerWidth;
      } else {
        globalThis.innerWidth = previousInnerWidth;
      }
    }
  });
}
