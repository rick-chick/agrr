import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export const MAX_AGENTS_MD_LINES = 40;

export const REQUIRED_AGENTS_COMMANDS = [
  'scripts/run-rust-contract-tests.sh',
  '.cursor/skills/test-common/scripts/run-test-rust-domain.sh',
  '.cursor/skills/test-common/scripts/run-test-frontend.sh',
  '.cursor/skills/dev-docker/scripts/rebuild-restart.sh',
];

export const REQUIRED_AGENTS_SKILL_LINKS = [
  '.cursor/skills/test-common/SKILL.md',
  '.cursor/skills/tdd-on-edit/SKILL.md',
  '.cursor/skills/dev-docker/SKILL.md',
  '.cursor/skills/error-investigation/SKILL.md',
];

function extractNormPrioritySection(content) {
  const match = content.match(/## Norm priority\n\n([\s\S]*?)(?=\n## )/);
  return match ? match[1] : null;
}

export function checkAgentsMd(rootDir) {
  const errors = [];
  const agentsPath = join(rootDir, 'AGENTS.md');
  if (!existsSync(agentsPath)) {
    return { ok: false, errors: ['AGENTS.md: missing'] };
  }

  const content = readFileSync(agentsPath, 'utf8');
  const lineCount = content.split('\n').length;

  if (lineCount > MAX_AGENTS_MD_LINES) {
    errors.push(`AGENTS.md: ${lineCount} lines exceeds max ${MAX_AGENTS_MD_LINES}`);
  }
  if (/ARCHITECTURE\.md/i.test(content)) {
    errors.push('AGENTS.md: must not reference ARCHITECTURE.md');
  }
  if (/LAYER-RULES/i.test(content)) {
    errors.push('AGENTS.md: must not reference LAYER-RULES');
  }
  if (/\/home\//.test(content)) {
    errors.push('AGENTS.md: must not contain host-specific absolute paths');
  }

  for (const command of REQUIRED_AGENTS_COMMANDS) {
    if (!content.includes(command)) {
      errors.push(`AGENTS.md: missing required command ${command}`);
    }
  }
  for (const link of REQUIRED_AGENTS_SKILL_LINKS) {
    if (!content.includes(link)) {
      errors.push(`AGENTS.md: missing required skill link ${link}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

export function checkClaudeMdNormPriority(rootDir) {
  const errors = [];
  const claudePath = join(rootDir, 'CLAUDE.md');
  if (!existsSync(claudePath)) {
    return { ok: false, errors: ['CLAUDE.md: missing'] };
  }

  const content = readFileSync(claudePath, 'utf8');
  const normSection = extractNormPrioritySection(content);
  if (!normSection) {
    return { ok: false, errors: ['CLAUDE.md: Norm priority section not found'] };
  }

  if (/ARCHITECTURE\.md/i.test(normSection)) {
    errors.push('CLAUDE.md Norm priority: must not include ARCHITECTURE.md');
  }

  const firstItem = normSection.match(/^\d+\.\s+(.+)$/m);
  if (!firstItem || !/Observable tests/i.test(firstItem[1])) {
    errors.push('CLAUDE.md Norm priority: item 1 must be Observable tests');
  }

  return { ok: errors.length === 0, errors };
}

export function checkAgentsMdContract(rootDir) {
  const agents = checkAgentsMd(rootDir);
  const claude = checkClaudeMdNormPriority(rootDir);
  const errors = [...agents.errors, ...claude.errors];
  return { ok: errors.length === 0, errors };
}
