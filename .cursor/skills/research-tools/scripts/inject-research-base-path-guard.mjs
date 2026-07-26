#!/usr/bin/env node
/**
 * VitePress (base=/research/) strips the base prefix in the browser URL after client nav,
 * e.g. /research/research_reports/... → /research_reports/...
 * Static hosting only serves files under /research/*, so reload 404s / shows blank.
 * This guard restores the /research prefix on load and keeps it in history updates.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');
const MARKER_START = '<!-- agrr-research-base-path-guard:start -->';
const MARKER_END = '<!-- agrr-research-base-path-guard:end -->';

const SNIPPET = `${MARKER_START}
<script>
(function () {
  var RESEARCH_BASE = '/research';
  function withResearchPrefix(pathname) {
    if (pathname.indexOf('/research_reports/') === 0) return RESEARCH_BASE + pathname;
    if (pathname.indexOf('/en/research_reports/') === 0) return RESEARCH_BASE + pathname;
    return pathname;
  }
  var fixed = withResearchPrefix(location.pathname);
  if (fixed !== location.pathname) {
    location.replace(fixed + location.search + location.hash);
    return;
  }
  function normalizeUrl(url) {
    if (typeof url !== 'string') return url;
    try {
      var parsed = new URL(url, location.origin);
      var nextPath = withResearchPrefix(parsed.pathname);
      if (nextPath === parsed.pathname) return url;
      return nextPath + parsed.search + parsed.hash;
    } catch (e) {
      return url;
    }
  }
  ['pushState', 'replaceState'].forEach(function (method) {
    var original = history[method];
    history[method] = function (state, title, url) {
      return original.call(this, state, title, normalizeUrl(url));
    };
  });
})();
</script>
${MARKER_END}`;

function walkHtmlFiles(dir) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      results.push(...walkHtmlFiles(fullPath));
      continue;
    }
    if (entry.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

function injectSnippet(content) {
  if (content.includes(MARKER_START)) {
    return content.replace(
      new RegExp(`${MARKER_START}[\\s\\S]*?${MARKER_END}`, 'm'),
      SNIPPET
    );
  }
  if (!content.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return content.replace(/<\/head>/i, `${SNIPPET}\n</head>`);
}

let updated = 0;
const failures = [];
for (const path of walkHtmlFiles(RESEARCH_DIR)) {
  const content = readFileSync(path, 'utf8');
  try {
    const next = injectSnippet(content);
    if (next === content) {
      continue;
    }
    writeFileSync(path, next, 'utf8');
    updated += 1;
  } catch (error) {
    failures.push(`${path}: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error('[inject-research-base-path-guard] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-base-path-guard] updated ${updated} HTML file(s)`);
