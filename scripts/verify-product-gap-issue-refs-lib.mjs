import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const SKILL_ROOT = '.cursor/skills/product-gap-to-issues';

const PATHS = {
  issuePackTemplate: join(SKILL_ROOT, 'references/issue-pack-template.md'),
  skill: join(SKILL_ROOT, 'SKILL.md'),
  artifacts: join(SKILL_ROOT, 'references/artifacts.md'),
  automationPrompt: join(SKILL_ROOT, 'references/automation-prompt.md'),
};

/** Extract markdown fenced blocks from a file (```markdown ... ```). */
function extractMarkdownBlocks(content) {
  const blocks = [];
  const re = /```markdown\n([\s\S]*?)```/g;
  let match;
  while ((match = re.exec(content)) !== null) {
    blocks.push(match[1]);
  }
  return blocks;
}

/** Return the ## 参照 section body from a markdown block, or empty string. */
function extractRefsSection(block) {
  const match = block.match(/## 参照\n([\s\S]*?)(?=\n## |\n*$)/);
  return match ? match[1] : '';
}

export async function verifyProductGapIssueRefs(repoRoot) {
  const errors = [];

  const read = async (rel) => readFile(join(repoRoot, rel), 'utf8');

  const [issuePack, skill, artifacts, automationPrompt] = await Promise.all([
    read(PATHS.issuePackTemplate),
    read(PATHS.skill),
    read(PATHS.artifacts),
    read(PATHS.automationPrompt),
  ]);

  // issue-pack-template: Epic + child 参照 sections must not cite tmp/product-gap/
  const blocks = extractMarkdownBlocks(issuePack);
  const epicBlock = blocks.find((b) => b.includes('## 子 issue（v1）'));
  const childBlock = blocks.find((b) => b.includes('## 親 epic'));

  if (!epicBlock) {
    errors.push('issue-pack-template.md: Epic markdown block not found');
  } else {
    const epicRefs = extractRefsSection(epicBlock);
    if (epicRefs.includes('tmp/product-gap/')) {
      errors.push('issue-pack-template.md: Epic 参照 must not contain tmp/product-gap/ paths');
    }
    if (!issuePack.includes('tmp/product-gap/') || !issuePack.includes('禁止')) {
      errors.push('issue-pack-template.md: must document tmp/product-gap/ prohibition for GitHub issue 参照');
    }
  }

  if (!childBlock) {
    errors.push('issue-pack-template.md: child issue markdown block not found');
  } else {
    const childRefs = extractRefsSection(childBlock);
    if (childRefs.includes('tmp/product-gap/')) {
      errors.push('issue-pack-template.md: child issue 参照 must not contain tmp/product-gap/ paths');
    }
  }

  // SKILL.md §フェーズ9
  const phase9Match = skill.match(/## フェーズ 9[\s\S]*?(?=\n## )/);
  if (!phase9Match) {
    errors.push('SKILL.md: §フェーズ9 section not found');
  } else if (!phase9Match[0].includes('tmp/product-gap/')) {
    errors.push('SKILL.md: §フェーズ9 must mention not putting tmp/product-gap/ in issue body');
  }

  // artifacts.md: conversion procedure before gh issue create
  if (!artifacts.includes('gh issue create') || !artifacts.includes('変換')) {
    errors.push('artifacts.md: 完了報告 must document converting issue-pack refs before gh issue create');
  }

  // automation-prompt.md: consistent constraint
  if (
    !automationPrompt.includes('tmp/product-gap/') ||
    (!automationPrompt.includes('参照') && !automationPrompt.includes('reference'))
  ) {
    errors.push('automation-prompt.md: must state issue body refs exclude tmp/product-gap/');
  }

  return { ok: errors.length === 0, errors };
}
