import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const DOMAIN_SRC = 'crates/agrr-domain/src';
const DOMAIN_CARGO = 'crates/agrr-domain/Cargo.toml';
const SERVER_SRC = 'crates/agrr-server/src';
const FE_COMPONENTS = 'frontend/src/app/components';
const FE_DOMAIN = 'frontend/src/app/domain';

const DOMAIN_FORBIDDEN_USE = [
  { id: 'R1', pattern: /\buse\s+axum\b/, label: 'axum' },
  { id: 'R1', pattern: /\buse\s+sqlx\b/, label: 'sqlx' },
  { id: 'R1', pattern: /\buse\s+reqwest\b/, label: 'reqwest' },
  { id: 'R1', pattern: /\buse\s+tokio::/, label: 'tokio::' },
  { id: 'R1', pattern: /\buse\s+hyper::/, label: 'hyper::' },
  { id: 'R1', pattern: /\bUtc::now\s*\(/, label: 'Utc::now()' },
  { id: 'R1', pattern: /\buse\s+chrono::/, label: 'chrono::' },
];

const DOMAIN_FORBIDDEN_DEPS = ['axum', 'sqlx', 'reqwest', 'tokio', 'hyper'];

const R7_EXEMPT_FILES = new Set([
  'auth.rs',
  'auth_test.rs',
  'cable.rs',
  'fallback.rs',
  'routes.rs',
  'security_headers.rs',
  'masters_rate_limit.rs',
  'main.rs',
  'lib.rs',
]);

const R7_EXEMPT_HANDLERS = new Set([
  'gone',
  'index_contact_messages',
  'download_content',
  'upload_content',
  'auth_me',
  'wizard_farm_sizes',
]);

function walkFiles(absDir, predicate) {
  const files = [];
  if (!existsSync(absDir)) return files;
  for (const entry of readdirSync(absDir, { withFileTypes: true })) {
    const abs = join(absDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkFiles(abs, predicate));
    } else if (predicate(entry.name)) {
      files.push(abs);
    }
  }
  return files;
}

function relPath(rootDir, absPath) {
  return relative(rootDir, absPath).replace(/\\/g, '/');
}

function extractFunctions(content) {
  const functions = new Map();
  const re = /(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+(\w+)(?:<[^>]*>)?\s*\(/g;
  let match;
  while ((match = re.exec(content)) !== null) {
    const name = match[1];
    const braceStart = content.indexOf('{', match.index);
    if (braceStart < 0) continue;
    let depth = 1;
    let i = braceStart + 1;
    while (i < content.length && depth > 0) {
      if (content[i] === '{') depth += 1;
      else if (content[i] === '}') depth -= 1;
      i += 1;
    }
    functions.set(name, content.slice(braceStart + 1, i - 1));
  }
  return functions;
}

function isThinRunDelegation(body) {
  const trimmed = body.replace(/\/\/.*$/gm, '').trim();
  return /\brun_[a-z0-9_]+\s*\(/.test(trimmed);
}

function hasInteractorDelegation(name, functions, seen = new Set()) {
  if (seen.has(name)) return false;
  seen.add(name);
  const body = functions.get(name);
  if (!body) return false;
  if (/\binteractor\b/i.test(body)) return true;
  if (isThinRunDelegation(body)) return true;
  const calls = [...body.matchAll(/\b([a-z_][a-z0-9_]*)\s*\(/g)].map((m) => m[1]);
  for (const callee of calls) {
    if (functions.has(callee) && hasInteractorDelegation(callee, functions, seen)) {
      return true;
    }
  }
  return false;
}

function collectRouteHandlers(content) {
  const handlers = new Set();
  const routeRe = /\b(get|post|put|patch|delete)\((\w+)\)/g;
  let match;
  while ((match = routeRe.exec(content)) !== null) {
    handlers.add(match[2]);
  }
  return handlers;
}

function checkDomainImports(rootDir) {
  const violations = [];
  const domainDir = join(rootDir, DOMAIN_SRC);
  for (const absPath of walkFiles(domainDir, (name) => name.endsWith('.rs'))) {
    const content = readFileSync(absPath, 'utf8');
    const file = relPath(rootDir, absPath);
    for (const { id, pattern, label } of DOMAIN_FORBIDDEN_USE) {
      if (pattern.test(content)) {
        violations.push({ ruleId: id, file, message: `forbidden ${label}` });
      }
    }
  }
  return violations;
}

function checkDomainCargo(rootDir) {
  const violations = [];
  const cargoPath = join(rootDir, DOMAIN_CARGO);
  if (!existsSync(cargoPath)) return violations;
  const content = readFileSync(cargoPath, 'utf8');
  const depsSection = content.match(/\[dependencies\]([\s\S]*?)(?:\n\[|$)/);
  if (!depsSection) return violations;
  for (const dep of DOMAIN_FORBIDDEN_DEPS) {
    const depRe = new RegExp(`^\\s*${dep}\\s*=`, 'm');
    if (depRe.test(depsSection[1])) {
      violations.push({
        ruleId: 'R1',
        file: DOMAIN_CARGO,
        message: `forbidden dependency ${dep}`,
      });
    }
  }
  return violations;
}

function checkGatewayDefault(rootDir) {
  const violations = [];
  const domainDir = join(rootDir, DOMAIN_SRC);
  const pattern = /\w+Gateway::default\s*\(/;
  for (const absPath of walkFiles(domainDir, (name) => name.endsWith('.rs'))) {
    const content = readFileSync(absPath, 'utf8');
    if (pattern.test(content)) {
      violations.push({
        ruleId: 'R2',
        file: relPath(rootDir, absPath),
        message: 'gateway obtained via ::default()',
      });
    }
  }
  return violations;
}

function checkPresenters(rootDir) {
  const violations = [];
  const serverDir = join(rootDir, SERVER_SRC);
  for (const absPath of walkFiles(serverDir, (name) => name.includes('presenter') && name.endsWith('.rs'))) {
    const content = readFileSync(absPath, 'utf8');
    const file = relPath(rootDir, absPath);
    if (/\bagrr-adapters-/.test(content) || /\bagrr_adapters_/.test(content)) {
      violations.push({ ruleId: 'R6', file, message: 'presenter imports agrr-adapters crate' });
    }
    if (/\bSqlite\b/.test(content) || /\bGateway::new\b/.test(content)) {
      violations.push({ ruleId: 'R6', file, message: 'presenter uses Sqlite or Gateway::new' });
    }
  }
  return violations;
}

function checkRouteHandlers(rootDir) {
  const violations = [];
  const serverDir = join(rootDir, SERVER_SRC);
  for (const absPath of walkFiles(serverDir, (name) => name.endsWith('.rs'))) {
    const base = absPath.split('/').pop();
    if (R7_EXEMPT_FILES.has(base)) continue;
    const content = readFileSync(absPath, 'utf8');
    if (!content.includes('Router::new')) continue;
    const functions = extractFunctions(content);
    const handlers = collectRouteHandlers(content);
    const file = relPath(rootDir, absPath);
    for (const handler of handlers) {
      if (R7_EXEMPT_HANDLERS.has(handler)) continue;
      if (!functions.has(handler)) continue;
      if (!hasInteractorDelegation(handler, functions)) {
        violations.push({
          ruleId: 'R7',
          file,
          message: `route handler ${handler} lacks interactor delegation`,
        });
      }
    }
  }
  return violations;
}

function checkFrontendImports(rootDir, relDir, ruleId, forbiddenPattern) {
  const violations = [];
  const absDir = join(rootDir, relDir);
  for (const absPath of walkFiles(absDir, (name) => name.endsWith('.ts'))) {
    const content = readFileSync(absPath, 'utf8');
    if (forbiddenPattern.test(content)) {
      violations.push({
        ruleId,
        file: relPath(rootDir, absPath),
        message: 'forbidden import path',
      });
    }
  }
  return violations;
}

export function runArchitectureGuard(rootDir) {
  const violations = [
    ...checkDomainImports(rootDir),
    ...checkDomainCargo(rootDir),
    ...checkGatewayDefault(rootDir),
    ...checkPresenters(rootDir),
    ...checkRouteHandlers(rootDir),
    ...checkFrontendImports(
      rootDir,
      FE_COMPONENTS,
      'FE-COMPONENTS',
      /from\s+['"]\.\.\/adapters\//,
    ),
    ...checkFrontendImports(
      rootDir,
      FE_DOMAIN,
      'FE-DOMAIN',
      /from\s+['"](?:\.\.\/)+(?:adapters|components)\//,
    ),
  ];
  return { ok: violations.length === 0, violations };
}

export function formatViolations(violations) {
  return violations.map((v) => `[${v.ruleId}] ${v.file}: ${v.message}`);
}
