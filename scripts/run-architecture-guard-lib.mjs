import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const DOMAIN_FORBIDDEN_USE_PATTERNS = [
  { id: 'R1', regex: /\buse\s+axum\b|\baxum::/ },
  { id: 'R1', regex: /\buse\s+sqlx\b|\bsqlx::/ },
  { id: 'R1', regex: /\buse\s+reqwest\b|\breqwest::/ },
  { id: 'R1', regex: /\btokio::/ },
  { id: 'R1', regex: /\bhyper::/ },
  { id: 'R1', regex: /\bUtc::now\s*\(/ },
  { id: 'R1', regex: /\buse\s+chrono\b|\bchrono::/ },
];

const DOMAIN_FORBIDDEN_DEPS = ['axum', 'sqlx', 'reqwest', 'tokio', 'hyper'];

const GATEWAY_DEFAULT_PATTERN = /(?<!Default::)(?<!unwrap_or_)(?<!or_)\b[A-Z][A-Za-z0-9_]*\.default\s*\(/;

const PRESENTER_ADAPTER_IMPORT = /\bagrr[-_]adapters[-_]/;

const PRESENTER_SQLITE_PATTERN = /\bSqlite\b|Gateway::new\s*\(/;

const FRONTEND_COMPONENT_ADAPTER_IMPORT = /['"]\.\.\/adapters\//;

const FRONTEND_DOMAIN_FORBIDDEN_IMPORT = /['"]\.\.\/adapters\/|['"]\.\.\/components\//;

const R7_DELEGATION_PATTERNS = [
  /interactor/i,
  /\brun_(add_crop|add_field|remove_field|adjust_plan)\s*\(/,
  /\btrigger_scheduler_weather_update\s*\(/,
];

const R7_EXEMPT_ROUTE_PATTERNS = [
  /^\/auth\//,
  /^\/\{locale\}\/auth\//,
  /^\/cable$/,
  /^\/api\/v1\/health$/,
  /^\/api\/v1\/backdoor\//,
  /^\/api\/v1\/internal\/jobs\//,
  /^\/api\/v1\/auth\/me$/,
  /^\/api\/v1\/contact_messages$/,
  /^\/api\/v1\/masters\/crops\/\{crop_id\}\/agricultural_tasks/,
  /^\/api\/v1\/public_plans\/farm_sizes$/,
  /^\/api\/v1\/plans\/\{plan_id\}\/work_records\/\{record_id\}\/photos\/\{photo_id\}\/content$/,
];

function walkFiles(absDir, relDir, predicate, files = []) {
  if (!existsSync(absDir)) return files;
  for (const entry of readdirSync(absDir, { withFileTypes: true })) {
    const rel = relDir ? join(relDir, entry.name) : entry.name;
    const abs = join(absDir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(abs, rel, predicate, files);
    } else if (entry.isFile() && predicate(entry.name)) {
      files.push(rel);
    }
  }
  return files;
}

function readText(rootDir, relPath) {
  return readFileSync(join(rootDir, relPath), 'utf8');
}

function pushViolation(violations, ruleId, file, message) {
  violations.push({ ruleId, file, message });
}

function checkDomainSource(rootDir, violations) {
  const domainSrc = join(rootDir, 'crates/agrr-domain/src');
  const files = walkFiles(domainSrc, 'crates/agrr-domain/src', (name) => name.endsWith('.rs'));
  for (const relPath of files) {
    const content = readText(rootDir, relPath);
    for (const { id, regex } of DOMAIN_FORBIDDEN_USE_PATTERNS) {
      if (regex.test(content)) {
        pushViolation(violations, id, relPath, `forbidden framework/runtime import or call (${regex})`);
      }
    }
    if (GATEWAY_DEFAULT_PATTERN.test(content)) {
      pushViolation(violations, 'R2', relPath, 'gateway retrieval via *.default()');
    }
  }
}

function parseDependencyNames(cargoToml) {
  const section = cargoToml.match(/\[dependencies\]([\s\S]*?)(?:\n\[|$)/);
  if (!section) return [];
  return [...section[1].matchAll(/^([A-Za-z0-9_-]+)\s*=/gm)].map((m) => m[1]);
}

function checkDomainCargo(rootDir, violations) {
  const relPath = 'crates/agrr-domain/Cargo.toml';
  const abs = join(rootDir, relPath);
  if (!existsSync(abs)) {
    pushViolation(violations, 'R1', relPath, 'missing Cargo.toml');
    return;
  }
  const deps = parseDependencyNames(readFileSync(abs, 'utf8'));
  for (const forbidden of DOMAIN_FORBIDDEN_DEPS) {
    if (deps.includes(forbidden)) {
      pushViolation(violations, 'R1', relPath, `forbidden dependency ${forbidden}`);
    }
  }
}

function checkPresenterFiles(rootDir, violations) {
  const serverSrc = join(rootDir, 'crates/agrr-server/src');
  const files = walkFiles(serverSrc, 'crates/agrr-server/src', (name) => /presenter/i.test(name) && name.endsWith('.rs'));
  for (const relPath of files) {
    const content = readText(rootDir, relPath);
    if (PRESENTER_ADAPTER_IMPORT.test(content)) {
      pushViolation(violations, 'R6', relPath, 'presenter imports agrr-adapters-* crate');
    }
    if (PRESENTER_SQLITE_PATTERN.test(content)) {
      pushViolation(violations, 'R6', relPath, 'presenter contains Sqlite or Gateway::new');
    }
  }
}

function extractHandlersFromRouteTail(tail) {
  const handlers = [];
  const methodRe = /(?:get|post|put|patch|delete)\((\w+)\)/g;
  let match;
  while ((match = methodRe.exec(tail)) !== null) {
    handlers.push(match[1]);
  }
  return handlers;
}

function extractBalancedParenGroup(source, openParenIndex) {
  if (source[openParenIndex] !== '(') return null;
  let depth = 0;
  for (let index = openParenIndex; index < source.length; index += 1) {
    const ch = source[index];
    if (ch === '(') depth += 1;
    if (ch === ')') {
      depth -= 1;
      if (depth === 0) return source.slice(openParenIndex + 1, index);
    }
  }
  return null;
}

function extractRouteHandlers(source) {
  const routes = [];
  let searchFrom = 0;
  while (searchFrom < source.length) {
    const routeIdx = source.indexOf('.route(', searchFrom);
    if (routeIdx < 0) break;
    const openParen = routeIdx + '.route'.length;
    const args = extractBalancedParenGroup(source, openParen);
    if (!args) {
      searchFrom = routeIdx + 1;
      continue;
    }
    const pathMatch = args.match(/^\s*"([^"]+)"/);
    if (pathMatch) {
      const routePath = pathMatch[1];
      const tail = args.slice(pathMatch[0].length).replace(/^\s*,\s*/, '');
      for (const handler of extractHandlersFromRouteTail(tail)) {
        routes.push({ routePath, handler });
      }
    }
    searchFrom = openParen + args.length + 2;
  }
  return routes;
}

function isTopLevelRoutePath(routePath) {
  return (
    routePath.startsWith('/api/') ||
    routePath.startsWith('/auth/') ||
    routePath.startsWith('/{locale}/') ||
    routePath === '/cable'
  );
}

function extractFunctionBody(source, fnName) {
  const fnRe = new RegExp(`(?:pub(?:\\(crate\\))?\\s+)?(?:async\\s+)?fn\\s+${fnName}\\s*\\([^)]*\\)[^{]*\\{`, 's');
  const match = fnRe.exec(source);
  if (!match) return null;
  let index = match.index + match[0].length;
  let depth = 1;
  while (index < source.length && depth > 0) {
    const ch = source[index];
    if (ch === '{') depth += 1;
    if (ch === '}') depth -= 1;
    index += 1;
  }
  return source.slice(match.index, index);
}

function listSameFileFunctionNames(source) {
  const names = new Set();
  const fnRe = /(?:pub(?:\(crate\))?\s+)?(?:async\s+)?fn\s+([a-z_][a-z0-9_]*)\s*\(/g;
  let match;
  while ((match = fnRe.exec(source)) !== null) {
    names.add(match[1]);
  }
  return names;
}

function collectReachableBodies(source, rootBody, functionNames) {
  const bodies = [rootBody];
  const visited = new Set();
  const queue = [rootBody];
  const callRe = /\b([a-z_][a-z0-9_]*)\s*\(/g;

  while (queue.length > 0) {
    const body = queue.shift();
    let match;
    while ((match = callRe.exec(body)) !== null) {
      const callee = match[1];
      if (!functionNames.has(callee) || visited.has(callee)) continue;
      visited.add(callee);
      const calleeBody = extractFunctionBody(source, callee);
      if (!calleeBody) continue;
      bodies.push(calleeBody);
      queue.push(calleeBody);
    }
  }
  return bodies;
}

function isR7RouteExempt(routePath) {
  if (!isTopLevelRoutePath(routePath)) return true;
  return R7_EXEMPT_ROUTE_PATTERNS.some((pattern) => pattern.test(routePath));
}

function handlerDelegatesToInteractor(source, handlerName, functionNames) {
  const body = extractFunctionBody(source, handlerName);
  if (!body) return false;
  const bodies = collectReachableBodies(source, body, functionNames);
  if (bodies.some((candidate) => R7_DELEGATION_PATTERNS.some((pattern) => pattern.test(candidate)))) {
    return true;
  }
  if (/\b\w+\.call\s*\(/.test(body) && /Interactor::new/.test(source)) {
    return true;
  }
  return false;
}

function checkRouteHandlers(rootDir, violations) {
  const serverSrc = join(rootDir, 'crates/agrr-server/src');
  const files = walkFiles(serverSrc, 'crates/agrr-server/src', (name) => name.endsWith('.rs'));
  for (const relPath of files) {
    const content = readText(rootDir, relPath);
    if (!content.includes('.route(')) continue;
    const functionNames = listSameFileFunctionNames(content);
    for (const { routePath, handler } of extractRouteHandlers(content)) {
      if (isR7RouteExempt(routePath)) continue;
      if (!handlerDelegatesToInteractor(content, handler, functionNames)) {
        pushViolation(
          violations,
          'R7',
          relPath,
          `route handler ${handler} (${routePath}) missing interactor delegation pattern`,
        );
      }
    }
  }
}

function checkFrontendComponents(rootDir, violations) {
  const componentDir = join(rootDir, 'frontend/src/app/components');
  const files = walkFiles(componentDir, 'frontend/src/app/components', (name) => name.endsWith('.ts'));
  for (const relPath of files) {
    const content = readText(rootDir, relPath);
    if (FRONTEND_COMPONENT_ADAPTER_IMPORT.test(content)) {
      pushViolation(violations, 'FRONTEND', relPath, 'component imports ../adapters/');
    }
  }
}

function checkFrontendDomain(rootDir, violations) {
  const domainDir = join(rootDir, 'frontend/src/app/domain');
  const files = walkFiles(domainDir, 'frontend/src/app/domain', (name) => name.endsWith('.ts'));
  for (const relPath of files) {
    const content = readText(rootDir, relPath);
    if (FRONTEND_DOMAIN_FORBIDDEN_IMPORT.test(content)) {
      pushViolation(violations, 'FRONTEND', relPath, 'domain imports ../adapters/ or ../components/');
    }
  }
}

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, violations: Array<{ ruleId: string, file: string, message: string }> }}
 */
export function runArchitectureGuard(repoRoot) {
  const violations = [];
  checkDomainSource(repoRoot, violations);
  checkDomainCargo(repoRoot, violations);
  checkPresenterFiles(repoRoot, violations);
  checkRouteHandlers(repoRoot, violations);
  checkFrontendComponents(repoRoot, violations);
  checkFrontendDomain(repoRoot, violations);
  return { ok: violations.length === 0, violations };
}

/**
 * @param {string} repoRoot
 * @returns {number} exit code
 */
export function runArchitectureGuardCli(repoRoot) {
  const { ok, violations } = runArchitectureGuard(repoRoot);
  if (!ok) {
    for (const violation of violations) {
      const rel = relative(repoRoot, join(repoRoot, violation.file));
      process.stderr.write(`${rel}: [${violation.ruleId}] ${violation.message}\n`);
    }
  }
  return ok ? 0 : 1;
}
