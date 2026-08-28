import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  extractKeywords,
  scoreDuplicate,
  validateConfirmedFinding,
  renderIssueBody,
} from './collect-critical-findings.mjs';

describe('collect-critical-findings', () => {
  it('extractKeywords strips priority prefix', () => {
    const kw = extractKeywords('[P0][bug] WebSocket cable subscription ignored');
    assert.ok(kw.includes('websocket'));
    assert.ok(kw.includes('subscription'));
  });

  it('validateConfirmedFinding requires repro_steps', () => {
    const errors = validateConfirmedFinding({
      id: 'F-test-01',
      status: 'CONFIRMED',
      evidence: [{ path: 'a.rs', lines: 'L1' }],
      acceptance_criteria: ['fix'],
      suggested_issue_title: '[P0][bug] x',
    });
    assert.ok(errors.some((e) => e.includes('repro_steps')));
  });

  it('scoreDuplicate ranks open issues higher', () => {
    const finding = {
      suggested_issue_title: '[P0][bug] WebSocket cable subscription',
      evidence: [{ path: 'crates/agrr-server/src/cable.rs' }],
    };
    const issues = [
      { number: 1, title: '[P0][bug] WebSocket cable handles one subscription', state: 'OPEN' },
      { number: 2, title: 'Unrelated issue', state: 'CLOSED' },
    ];
    const scored = scoreDuplicate(finding, issues);
    assert.equal(scored[0].number, 1);
    assert.ok(scored[0].score >= 5);
  });

  it('renderIssueBody includes repro and evidence', () => {
    const body = renderIssueBody({
      id: 'F-test-01',
      category: 'core-availability',
      title: 'Test',
      user_impact: 'Users cannot proceed',
      repro_steps: ['Open farm', 'Navigate to plan'],
      evidence: [{ path: 'src/cable.rs', lines: 'L10', note: 'return early' }],
      acceptance_criteria: ['Fix subscription'],
    });
    assert.match(body, /Open farm/);
    assert.match(body, /src\/cable\.rs/);
    assert.match(body, /test-common GREEN/);
  });
});
