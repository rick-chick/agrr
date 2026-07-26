#!/usr/bin/env node
/**
 * On research 404.html, redirect extensionless report paths to their .html object
 * (recovery for bookmarks / external links before VitePress link patch propagates).
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const NOT_FOUND_HTML = join(ROOT, 'public', 'research', '404.html');

const MARKER_START = '<!-- agrr-research-extensionless-redirect:start -->';
const MARKER_END = '<!-- agrr-research-extensionless-redirect:end -->';

const SNIPPET = `${MARKER_START}
<script>
(function () {
  var p = location.pathname;
  if (!p || p.endsWith('.html') || p.endsWith('/')) return;
  if (p.indexOf('/research_reports/') < 0) return;
  var target = p + '.html' + location.search + location.hash;
  location.replace(target);
})();
</script>
${MARKER_END}`;

let content = readFileSync(NOT_FOUND_HTML, 'utf8');
if (content.includes(MARKER_START)) {
  content = content.replace(
    new RegExp(`${MARKER_START}[\\s\\S]*?${MARKER_END}`, 'm'),
    SNIPPET
  );
} else if (content.match(/<\/head>/i)) {
  content = content.replace(/<\/head>/i, `${SNIPPET}\n</head>`);
} else {
  throw new Error('missing </head> in 404.html');
}
writeFileSync(NOT_FOUND_HTML, content, 'utf8');
console.log('[inject-research-extensionless-redirect] updated 404.html');
