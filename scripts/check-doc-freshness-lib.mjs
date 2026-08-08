import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative } from 'node:path';

const STALE_PATTERNS = [
  { name: 'lib/domain path', regex: /\blib\/domain\b/ },
  { name: 'app/controllers/api path', regex: /\bapp\/controllers\/api\b/ },
  { name: 'Rails 8 JSON API phrase', regex: /Rails 8 JSON API/ },
];

const SCAN_ROOTS = ['docs', '.cursor/rules'];
const SCAN_FILES = ['ARCHITECTURE.md', 'CLAUDE.md', 'AGENTS.md', 'README.md'];

function listMarkdownFiles(rootDir) {
  const files = [];
  for (const rel of SCAN_FILES) {
    const abs = join(rootDir, rel);
    if (existsSync(abs)) files.push(rel);
  }
  for (const scanRoot of SCAN_ROOTS) {
    const base = join(rootDir, scanRoot);
    if (!existsSync(base)) continue;
    walkMarkdown(base, scanRoot, files);
  }
  return files;
}

function walkMarkdown(absDir, relDir, files) {
  for (const entry of readdirSync(absDir, { withFileTypes: true })) {
    const rel = join(relDir, entry.name);
    const abs = join(absDir, entry.name);
    if (entry.isDirectory()) {
      walkMarkdown(abs, rel, files);
    } else if (entry.isFile() && (entry.name.endsWith('.md') || entry.name.endsWith('.mdc'))) {
      files.push(rel);
    }
  }
}

function isStalePathAllowlisted(relPath) {
  const normalized = relPath.replace(/\\/g, '/');
  if (normalized === 'docs/architecture/LAYER-RULES.md') return true;
  return normalized.startsWith('docs/migration/');
}

const LINK_SCAN_FILES = [
  'ARCHITECTURE.md',
  'CLAUDE.md',
  'AGENTS.md',
  'README.md',
  'docs/README.md',
  'docs/architecture/LAYER-RULES.md',
];

function listLinkCheckFiles(rootDir) {
  return LINK_SCAN_FILES.filter((rel) => existsSync(join(rootDir, rel)));
}

function isHistoricalBlock(content) {
  return /Status:\s*historical/i.test(content.slice(0, 500));
}

export function checkDocStalePaths(rootDir) {
  const errors = [];
  for (const relPath of listMarkdownFiles(rootDir)) {
    if (isStalePathAllowlisted(relPath)) continue;
    const content = readFileSync(join(rootDir, relPath), 'utf8');
    if (isHistoricalBlock(content)) continue;
    for (const { name, regex } of STALE_PATTERNS) {
      if (regex.test(content)) {
        errors.push(`${relPath}: stale pattern (${name})`);
      }
    }
  }
  return { ok: errors.length === 0, errors };
}

function isSkippableHref(href) {
  if (!href || href.includes('<') || href.includes('任意')) return true;
  if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('#')) return true;
  if (href.startsWith('mailto:')) return true;
  return false;
}

function resolveLink(fromFile, href, rootDir) {
  if (isSkippableHref(href)) return null;
  const [pathPart] = href.split('#');
  if (!pathPart) return null;
  const fromDir = dirname(join(rootDir, fromFile));
  const target = resolve(fromDir, pathPart);
  if (!target.startsWith(rootDir)) return null;
  return { target };
}

export function checkDocInternalLinks(rootDir) {
  const errors = [];
  const linkRegex = /(?<!!)\[([^\]]*)\]\(([^)]+)\)/g;
  for (const relPath of listLinkCheckFiles(rootDir)) {
    const content = readFileSync(join(rootDir, relPath), 'utf8');
    let match;
    while ((match = linkRegex.exec(content)) !== null) {
      const href = match[2].trim();
      const resolved = resolveLink(relPath, href, rootDir);
      if (!resolved) continue;
      const { target } = resolved;
      if (!existsSync(target)) {
        errors.push(
          `${relPath}: broken link ${href} → ${relative(rootDir, target)}`,
        );
      }
    }
  }
  return { ok: errors.length === 0, errors };
}
