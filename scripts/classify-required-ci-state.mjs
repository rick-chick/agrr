#!/usr/bin/env node
/**
 * Prints required CI aggregate state for workflow bash callers.
 * Reads CHECKS_JSON env (gh pr checks --json name,state).
 *
 * stdout: incomplete | failed | green
 */

import { classifyRequiredCiState } from './pr-agent-prep-lib.mjs';

const raw = process.env.CHECKS_JSON ?? '[]';
const checks = JSON.parse(raw);
process.stdout.write(classifyRequiredCiState(checks));
