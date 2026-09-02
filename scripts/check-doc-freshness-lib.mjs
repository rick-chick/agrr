import { readFileSync, readdirSync, existsSync } from 'node:fs';
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

const ALLOWED_ALWAYS_APPLY = [
  '.cursor/rules/git-operational-constraints.mdc',
  '.cursor/rules/tdd-on-edit.mdc',
  '.cursor/rules/docker-dev-agrr-server-rebuild.mdc',
  '.cursor/rules/test-common-entry.mdc',
];

const MAX_ALWAYS_APPLY_TOTAL_LINES = 80;

const CLAUDE_ALWAYS_APPLY_REFS = [
  '@.cursor/rules/git-operational-constraints.mdc',
  '@.cursor/rules/tdd-on-edit.mdc',
  '@.cursor/rules/docker-dev-agrr-server-rebuild.mdc',
  '@.cursor/rules/test-common-entry.mdc',
];

function countLines(absPath) {
  return readFileSync(absPath, 'utf8').split('\n').length;
}

function hasAlwaysApplyTrue(content) {
  return /alwaysApply:\s*true/.test(content);
}

export function checkAlwaysApplyRules(rootDir) {
  const errors = [];
  const rulesDir = join(rootDir, '.cursor/rules');
  if (!existsSync(rulesDir)) {
    return { ok: false, errors: ['.cursor/rules: missing'] };
  }

  const alwaysApplyFiles = [];
  for (const entry of readdirSync(rulesDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.mdc')) continue;
    const rel = `.cursor/rules/${entry.name}`;
    const content = readFileSync(join(rulesDir, entry.name), 'utf8');
    if (hasAlwaysApplyTrue(content)) {
      alwaysApplyFiles.push(rel);
    }
  }

  alwaysApplyFiles.sort();
  const allowed = [...ALLOWED_ALWAYS_APPLY].sort();
  if (alwaysApplyFiles.length !== allowed.length) {
    errors.push(
      `alwaysApply: true count ${alwaysApplyFiles.length}, expected ${allowed.length}: ${alwaysApplyFiles.join(', ')}`,
    );
  } else {
    for (let i = 0; i < allowed.length; i += 1) {
      if (alwaysApplyFiles[i] !== allowed[i]) {
        errors.push(
          `alwaysApply: true mismatch at index ${i}: got ${alwaysApplyFiles[i]}, expected ${allowed[i]}`,
        );
      }
    }
  }

  let totalLines = 0;
  for (const rel of ALLOWED_ALWAYS_APPLY) {
    const abs = join(rootDir, rel);
    if (!existsSync(abs)) {
      errors.push(`${rel}: missing`);
      continue;
    }
    totalLines += countLines(abs);
  }
  if (totalLines > MAX_ALWAYS_APPLY_TOTAL_LINES) {
    errors.push(
      `alwaysApply rules total lines ${totalLines}, max ${MAX_ALWAYS_APPLY_TOTAL_LINES}`,
    );
  }

  const claudePath = join(rootDir, 'CLAUDE.md');
  if (!existsSync(claudePath)) {
    errors.push('CLAUDE.md: missing');
  } else {
    const claude = readFileSync(claudePath, 'utf8');
    const sectionMatch = claude.match(
      /## Always-apply rules\n([\s\S]*?)(?=\n## |\n$)/,
    );
    if (!sectionMatch) {
      errors.push('CLAUDE.md: missing ## Always-apply rules section');
    } else {
      const refs = sectionMatch[1]
        .split('\n')
        .map((line) => line.trim())
        .filter((line) => line.startsWith('@.cursor/rules/'));
      const expected = [...CLAUDE_ALWAYS_APPLY_REFS];
      refs.sort();
      expected.sort();
      if (refs.length !== expected.length) {
        errors.push(
          `CLAUDE.md Always-apply refs count ${refs.length}, expected ${expected.length}`,
        );
      } else {
        for (let i = 0; i < expected.length; i += 1) {
          if (refs[i] !== expected[i]) {
            errors.push(
              `CLAUDE.md Always-apply ref mismatch: got ${refs[i]}, expected ${expected[i]}`,
            );
          }
        }
      }
    }
  }

  return { ok: errors.length === 0, errors };
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

const DOMAIN_SRC = 'crates/agrr-domain/src';
const BOUNDED_CONTEXT_EXCLUDE = new Set(['shared']);
const DEV_DOCKER_SCRIPTS = '.cursor/skills/dev-docker/scripts';

function listDomainContextDirs(rootDir) {
  const domainSrc = join(rootDir, DOMAIN_SRC);
  if (!existsSync(domainSrc)) return [];
  return readdirSync(domainSrc, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !BOUNDED_CONTEXT_EXCLUDE.has(entry.name))
    .map((entry) => entry.name)
    .sort();
}

function parseArchitectureBoundedContexts(rootDir) {
  const archPath = join(rootDir, 'ARCHITECTURE.md');
  if (!existsSync(archPath)) return null;
  const content = readFileSync(archPath, 'utf8');
  const match = content.match(
    /\*\*Bounded contexts\*\*[^:]*:\s*((?:`[^`]+`(?:,\s*)?)+)/,
  );
  if (!match) return null;
  return [...match[1].matchAll(/`([^`]+)`/g)]
    .map((m) => m[1])
    .filter((name) => !BOUNDED_CONTEXT_EXCLUDE.has(name))
    .sort();
}

export function checkBoundedContextSync(rootDir) {
  const errors = [];
  const actual = listDomainContextDirs(rootDir);
  const documented = parseArchitectureBoundedContexts(rootDir);
  if (!documented) {
    return { ok: false, errors: ['ARCHITECTURE.md: Bounded contexts list not found'] };
  }
  const actualSet = new Set(actual);
  const documentedSet = new Set(documented);
  for (const name of actual) {
    if (!documentedSet.has(name)) {
      errors.push(`ARCHITECTURE.md: missing bounded context ${name} (present in ${DOMAIN_SRC}/)`);
    }
  }
  for (const name of documented) {
    if (!actualSet.has(name)) {
      errors.push(`ARCHITECTURE.md: documents bounded context ${name} but ${DOMAIN_SRC}/${name}/ is missing`);
    }
  }
  return { ok: errors.length === 0, errors };
}

function extractMarkdownSection(content, heading) {
  const re = new RegExp(`## ${heading}\\n([\\s\\S]*?)(?=\\n## |\\n$)`);
  const match = content.match(re);
  return match ? match[1] : null;
}

function isScriptPath(value) {
  if (!value || value.includes('*') || value.includes('{')) return false;
  if (value.endsWith('.sh')) return true;
  return value.includes('/scripts/') || value.startsWith('scripts/');
}

function extractTableCommandPaths(section) {
  const paths = [];
  const rowRe = /^\|[^|]+\|\s*([^|]+)\|/gm;
  let match;
  while ((match = rowRe.exec(section)) !== null) {
    const cell = match[1];
    if (/^[-:]+$/.test(cell.trim())) continue;
    for (const tick of cell.matchAll(/`([^`]+)`/g)) {
      const value = tick[1].trim();
      if (!isScriptPath(value)) continue;
      if (value.includes('/')) {
        paths.push(value);
      } else {
        paths.push(`${DEV_DOCKER_SCRIPTS}/${value}`);
      }
    }
  }
  return paths;
}

function verifyScriptPaths(rootDir, relPaths, sourceLabel) {
  const errors = [];
  for (const relPath of relPaths) {
    const abs = join(rootDir, relPath);
    if (!existsSync(abs)) {
      errors.push(`${sourceLabel}: script path missing ${relPath}`);
    }
  }
  return errors;
}

export function checkCommandTableSync(rootDir) {
  const claudePath = join(rootDir, 'CLAUDE.md');
  if (!existsSync(claudePath)) {
    return { ok: false, errors: ['CLAUDE.md: missing'] };
  }
  const content = readFileSync(claudePath, 'utf8');
  const section = extractMarkdownSection(content, 'Commands');
  if (!section) {
    return { ok: false, errors: ['CLAUDE.md: Commands section not found'] };
  }
  const paths = extractTableCommandPaths(section);
  const errors = verifyScriptPaths(rootDir, paths, 'CLAUDE.md Commands');
  return { ok: errors.length === 0, errors };
}

export function checkAgentsCommandSync(rootDir) {
  const agentsPath = join(rootDir, 'AGENTS.md');
  if (!existsSync(agentsPath)) {
    return { ok: false, errors: ['AGENTS.md: missing'] };
  }
  const content = readFileSync(agentsPath, 'utf8');
  const section = extractMarkdownSection(content, 'Test commands');
  if (!section) {
    return { ok: false, errors: ['AGENTS.md: Test commands section not found'] };
  }
  const paths = extractTableCommandPaths(section);
  const errors = verifyScriptPaths(rootDir, paths, 'AGENTS.md');
  return { ok: errors.length === 0, errors };
}

const FALLBACK_RULE = '.cursor/rules/fallback.mdc';
const ERROR_INVESTIGATION_CHECKLIST =
  '.cursor/skills/error-investigation/references/CHECKLIST.md';

const DOMAIN_FALLBACK_REQUIRED_PHRASES = [
  { name: 'domain judgment scope', regex: /ドメイン判定/ },
  { name: 'fail-closed', regex: /fail-closed/i },
  { name: 'eligible: false', regex: /eligible:\s*false/i },
  { name: 'alternate algorithm prohibition', regex: /別アルゴリズム/ },
  { name: 'no-convenience-tech-debt cross-ref', regex: /no-convenience-tech-debt\.mdc/ },
  { name: 'P6 infrastructure cross-ref', regex: /P6/ },
];

export function checkDomainFallbackPolicy(rootDir) {
  const errors = [];
  const fallbackPath = join(rootDir, FALLBACK_RULE);
  if (!existsSync(fallbackPath)) {
    errors.push(`${FALLBACK_RULE}: missing`);
    return { ok: false, errors };
  }

  const fallbackContent = readFileSync(fallbackPath, 'utf8');
  for (const { name, regex } of DOMAIN_FALLBACK_REQUIRED_PHRASES) {
    if (!regex.test(fallbackContent)) {
      errors.push(`${FALLBACK_RULE}: missing required phrase (${name})`);
    }
  }

  const archPath = join(rootDir, 'ARCHITECTURE.md');
  if (!existsSync(archPath)) {
    errors.push('ARCHITECTURE.md: missing');
  } else {
    const archContent = readFileSync(archPath, 'utf8');
    if (!/## Domain fallback policy/i.test(archContent)) {
      errors.push('ARCHITECTURE.md: missing ## Domain fallback policy section');
    }
    if (!/fallback\.mdc/.test(archContent)) {
      errors.push('ARCHITECTURE.md: missing link to fallback.mdc');
    }
    if (!/ドメイン判定/.test(archContent)) {
      errors.push('ARCHITECTURE.md: domain fallback section must mention ドメイン判定');
    }
  }

  const checklistPath = join(rootDir, ERROR_INVESTIGATION_CHECKLIST);
  if (!existsSync(checklistPath)) {
    errors.push(`${ERROR_INVESTIGATION_CHECKLIST}: missing`);
  } else {
    const checklistContent = readFileSync(checklistPath, 'utf8');
    const linkMatch = checklistContent.match(
      /根本原因優先:\s*\[[^\]]*\]\(([^)]+)\)/,
    );
    if (!linkMatch) {
      errors.push(
        `${ERROR_INVESTIGATION_CHECKLIST}: missing resolvable fallback.mdc link after 根本原因優先`,
      );
    } else {
      const resolved = resolveLink(
        ERROR_INVESTIGATION_CHECKLIST,
        linkMatch[1].trim(),
        rootDir,
      );
      if (!resolved || !existsSync(resolved.target)) {
        errors.push(
          `${ERROR_INVESTIGATION_CHECKLIST}: broken fallback.mdc link (${linkMatch[1]})`,
        );
      } else if (
        relative(rootDir, resolved.target).replace(/\\/g, '/') !== FALLBACK_RULE
      ) {
        errors.push(
          `${ERROR_INVESTIGATION_CHECKLIST}: fallback link must target ${FALLBACK_RULE}`,
        );
      }
    }
  }

  return { ok: errors.length === 0, errors };
}
