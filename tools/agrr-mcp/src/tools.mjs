import { z } from 'zod';

const cropSetupProposalSchema = z.object({
  stages: z.array(z.record(z.unknown())),
  agricultural_tasks: z.array(z.record(z.unknown())),
  task_schedule_blueprints: z.array(z.record(z.unknown())),
});

/**
 * @param {import('./agrr-client.mjs').AgrrClient} client
 */
export function createAgrrMcpToolHandlers(client) {
  return {
    list_reference_crops: {
      description:
        'List reference crops from GET /api/v1/masters/crops (filters is_reference=true).',
      inputSchema: {
        region: z
          .enum(['jp', 'us', 'in'])
          .optional()
          .describe('Optional region filter'),
      },
      handler: async ({ region }) => {
        const crops = await client.listReferenceCrops(region ? { region } : {});
        return {
          content: [{ type: 'text', text: JSON.stringify(crops, null, 2) }],
        };
      },
    },
    get_crop_detail: {
      description: 'Fetch crop detail from GET /api/v1/masters/crops/{id}.',
      inputSchema: {
        crop_id: z.number().int().positive().describe('Crop id'),
      },
      handler: async ({ crop_id }) => {
        const crop = await client.getCropDetail(crop_id);
        return {
          content: [{ type: 'text', text: JSON.stringify(crop, null, 2) }],
        };
      },
    },
    propose_crop_setup: {
      description:
        'Validate a crop setup proposal via POST .../setup_proposal?mode=dry_run.',
      inputSchema: {
        crop_id: z.number().int().positive().describe('Target crop id'),
        proposal: cropSetupProposalSchema.describe(
          'CropSetupProposal JSON (stages, agricultural_tasks, task_schedule_blueprints)',
        ),
      },
      handler: async ({ crop_id, proposal }) => {
        const result = await client.proposeCropSetup(crop_id, proposal);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
    apply_crop_setup: {
      description:
        'Apply a validated crop setup proposal via POST .../setup_proposal?mode=apply.',
      inputSchema: {
        crop_id: z.number().int().positive().describe('Target crop id'),
        proposal: cropSetupProposalSchema.describe(
          'CropSetupProposal JSON (stages, agricultural_tasks, task_schedule_blueprints)',
        ),
      },
      handler: async ({ crop_id, proposal }) => {
        const result = await client.applyCropSetup(crop_id, proposal);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
  };
}

export const AGRR_MCP_TOOL_NAMES = [
  'list_reference_crops',
  'get_crop_detail',
  'propose_crop_setup',
  'apply_crop_setup',
];
