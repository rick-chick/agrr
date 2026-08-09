import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const AGENTS_PATH = 'AGENTS.md';
const CLAUDE_PATH = 'CLAUDE.md';

const REQUIRED_COMMANDS = [
  'scripts/run-rust-contract-tests.sh',
  '.cursor/skills/test-common/scripts/run-test-rust-domain.sh',
  '.cursor/skills/test-common/scripts/run-test-frontend.sh',
  '.cursor/skills/dev-docker/scripts/rebuild-restart.sh',
];

const REQUIRED_SKILL_LINKS = [
  '.cursor/skills/test-common/SKILL.md',
  'tdd-on-edit/SKILL.md',
  'dev-docker/SKILL.md',
  'error-investigation/SKILL.md',
];

const MAX_AGENTS_LINES = 40;

function normPrioritySection(claudeBody) {
  const match = claudeBody.match(/## Norm priority\r?\n([\s\S]*?)(?=\r?\n## |\r?\n$)/);
  return match ? match[1] : '';
}

export function verifyAgentsMd(rootDir) {
  const errors = [];
  const agentsPath = join(rootDir, AGENTS_PATH);
  const claudePath = join(rootDir, CLAUDE_PATH);

  if (!existsSync(agentsPath)) {
    return { ok: false, errors: [`${AGENTS_PATH}: missing`] };
  }
  if (!existsSync(claudePath)) {
    return { ok: false, errors: [`${CLAUDE_PATH}: missing`] };
  }

  const agentsBody = readFileSync(agentsPath, 'utf8');
  const claudeBody = readFileSync(claudePath, 'utf8');
  const agentsLines = agentsBody.split(/\r?\n/).length;

  if (agentsLines > MAX_AGENTS_LINES) {
    errors.push(`${AGENTS_PATH}: ${agentsLines} lines (max ${MAX_AGENTS_LINES})`);
  }

  if (/\bARCHITECTURE\.md\b/.test(agentsBody)) {
    errors.push(`${AGENTS_PATH}: must not reference ARCHITECTURE.md`);
  }

  if (/\bLAYER-RULES\b/.test(agentsBody)) {
    errors.push(`${AGENTS_PATH}: must not reference LAYER-RULES`);
  }

  if (/\/home\//.test(agentsBody)) {
    errors.push(`${AGENTS_PATH}: must not contain host-specific absolute paths`);
  }

  for (const cmd of REQUIRED_COMMANDS) {
    if (!agentsBody.includes(cmd)) {
      errors.push(`${AGENTS_PATH}: missing command ${cmd}`);
    }
  }

  for (const link of REQUIRED_SKILL_LINKS) {
    if (!agentsBody.includes(link)) {
      errors.push(`${AGENTS_PATH}: missing skill link ${link}`);
    }
  }

  const normSection = normPrioritySection(claudeBody);
  if (!normSection) {
    errors.push(`${CLAUDE_PATH}: Norm priority section missing`);
  } else {
    if (/\bARCHITECTURE\.md\b/.test(normSection)) {
      errors.push(`${CLAUDE_PATH}: Norm priority must not include ARCHITECTURE.md`);
    }
    const firstItem = normSection.match(/^\s*1\.\s+(.+)/m);
    if (!firstItem || !/Observable tests|run-rust-contract-tests\.sh/.test(firstItem[1])) {
      errors.push(`${CLAUDE_PATH}: Norm priority item 1 must be Observable tests`);
    }
  }

  return { ok: errors.length === 0, errors };
}
