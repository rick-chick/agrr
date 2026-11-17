import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const masterLayoutCss = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), '../../src/app/components/masters/_master-layout.css'),
  'utf8',
);

test('card-list grid stretches siblings so item-card row heights stay within layout contract', () => {
  const cardListBlock = masterLayoutCss.match(
    /\/\* ===== 2\. 一覧[\s\S]*?^\.card-list\s*\{[^}]+\}/m,
  );
  assert.ok(cardListBlock, 'expected .card-list rule in _master-layout.css');
  assert.match(
    cardListBlock[0],
    /align-items:\s*stretch/,
    'card-list rows must stretch grid items to uniform row track height',
  );
  assert.doesNotMatch(
    cardListBlock[0],
    /align-items:\s*start/,
    'align-items:start allows item-card height delta within the same row',
  );
});

test('card-list items pass stretch height to item-card', () => {
  assert.match(
    masterLayoutCss,
    /\.card-list__item\s*>\s*\.item-card[\s\S]*?align-self:\s*stretch/,
    'item-card should fill the stretched grid cell',
  );
});