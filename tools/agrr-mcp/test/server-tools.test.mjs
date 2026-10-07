import assert from 'node:assert/strict';
import test from 'node:test';

import { createAgrrMcpToolHandlers } from '../src/tools.mjs';
import { tomatoJpSetupProposal } from '../src/fixtures.mjs';

function createMockClient() {
  const calls = [];
  return {
    calls,
    listReferenceCrops: async (opts) => {
      calls.push(['listReferenceCrops', opts]);
      return [{ id: 1, name: 'トマト', region: 'jp', is_reference: true }];
    },
    getCropDetail: async (id) => {
      calls.push(['getCropDetail', id]);
      return { id, name: 'トマト', region: 'jp', crop_stages: [] };
    },
    proposeCropSetup: async (id, proposal) => {
      calls.push(['proposeCropSetup', id, proposal]);
      return { mode: 'dry_run', valid: true, normalized: proposal };
    },
  };
}

const EXPECTED_MCP_TOOL_NAMES = [
  'get_crop_detail',
  'list_reference_crops',
  'propose_crop_setup',
];

test('MCP tool handlers expose three crop setup tools (read-only API key)', () => {
  const tools = createAgrrMcpToolHandlers(createMockClient());
  assert.deepEqual(Object.keys(tools).sort(), [...EXPECTED_MCP_TOOL_NAMES].sort());
  assert.equal(tools.apply_crop_setup, undefined);
});

test('list_reference_crops delegates to client', async () => {
  const client = createMockClient();
  const tools = createAgrrMcpToolHandlers(client);
  const result = await tools.list_reference_crops.handler({ region: 'jp' });
  assert.equal(client.calls[0][0], 'listReferenceCrops');
  assert.match(result.content[0].text, /トマト/);
});

test('get_crop_detail delegates to client', async () => {
  const client = createMockClient();
  const tools = createAgrrMcpToolHandlers(client);
  await tools.get_crop_detail.handler({ crop_id: 5 });
  assert.deepEqual(client.calls[0], ['getCropDetail', 5]);
});

test('propose_crop_setup delegates dry_run to client', async () => {
  const client = createMockClient();
  const tools = createAgrrMcpToolHandlers(client);
  const proposal = tomatoJpSetupProposal();
  await tools.propose_crop_setup.handler({ crop_id: 9, proposal });
  assert.equal(client.calls[0][0], 'proposeCropSetup');
  assert.equal(client.calls[0][1], 9);
});
