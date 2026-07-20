#!/usr/bin/env node
/**
 * Classify primary PR merge dispatch eligibility from JSON input.
 *
 * Env: INPUT_JSON — fields for classifyPrimaryPrMergeDispatch
 * stdout: { eligible, reason? | dispatchKind? }
 */
import { classifyPrimaryPrMergeDispatch } from './pr-merge-worker-primary-dispatch-lib.mjs';

const input = JSON.parse(process.env.INPUT_JSON ?? '{}');
const result = classifyPrimaryPrMergeDispatch(input);
process.stdout.write(JSON.stringify(result));
