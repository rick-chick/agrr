import { E2E_BASELINE_PREFIX } from './ensure-e2e-baseline-bodies.mjs';
import { parseMasterList } from '../shared/baseline-ids-lib.mjs';

const PLAN_CREATE_READY_PREFIX = `${E2E_BASELINE_PREFIX} Plan Create Ready`;

/**
 * @typedef {{ get: (path: string) => Promise<TransportResponse>; post: (path: string, data: unknown) => Promise<TransportResponse> }} ApiTransport
 * @typedef {{ ok: boolean; status: number; json: () => Promise<unknown>; text: () => Promise<string> }} TransportResponse
 */

/**
 * @param {Response} response
 * @returns {TransportResponse}
 */
export function transportFromFetch(response) {
  return {
    ok: response.ok,
    status: response.status,
    json: () => response.json(),
    text: () => response.text(),
  };
}

/**
 * @param {string} base
 * @param {Record<string, string>} headers
 * @returns {ApiTransport}
 */
export function createFetchTransport(base, headers) {
  const origin = base.replace(/\/$/, '');
  const jsonHeaders = {
    ...headers,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  return {
    async get(path) {
      const response = await fetch(`${origin}${path}`, { headers: jsonHeaders });
      return transportFromFetch(response);
    },
    async post(path, data) {
      const response = await fetch(`${origin}${path}`, {
        method: 'POST',
        headers: jsonHeaders,
        body: JSON.stringify(data),
      });
      return transportFromFetch(response);
    },
  };
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 * @returns {ApiTransport}
 */
export function createPlaywrightTransport(api, base) {
  const origin = base.replace(/\/$/, '');
  const headers = { Accept: 'application/json' };
  return {
    async get(path) {
      const response = await api.get(`${origin}${path}`, { headers });
      return {
        ok: response.ok(),
        status: response.status(),
        json: () => response.json(),
        text: () => response.text(),
      };
    },
    async post(path, data) {
      const response = await api.post(`${origin}${path}`, {
        data,
        headers,
      });
      return {
        ok: response.ok(),
        status: response.status(),
        json: () => response.json(),
        text: () => response.text(),
      };
    },
  };
}

/**
 * @param {unknown} data
 * @returns {Record<string, unknown>[]}
 */
export function parseRows(data) {
  return parseMasterList(data);
}

/**
 * Poll farm show until weather_data_status is completed.
 *
 * @param {ApiTransport} transport
 * @param {number} farmId
 * @param {{ maxAttempts?: number; sleepMs?: number }} [options]
 */
export async function pollFarmWeatherCompleted(transport, farmId, options = {}) {
  const maxAttempts = options.maxAttempts ?? 180;
  const sleepMs = options.sleepMs ?? 1000;
  const path = `/api/v1/masters/farms/${farmId}`;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const response = await transport.get(path);
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`GET ${path} failed (${response.status}): ${body.slice(0, 300)}`);
    }
    const json = /** @type {Record<string, unknown>} */ (await response.json());
    const status = json['weather_data_status'];
    if (status === 'completed') {
      return;
    }
    if (status === 'failed') {
      throw new Error(`farm weather fetch failed: ${JSON.stringify(json).slice(0, 300)}`);
    }
    await new Promise((resolve) => setTimeout(resolve, sleepMs));
  }
  throw new Error(`farm weather did not reach completed within timeout (farmId=${farmId})`);
}

/**
 * @param {ApiTransport} transport
 * @param {number} cropId
 * @param {string} taskType
 * @returns {Promise<number>}
 */
async function ensureAgriculturalTaskByType(transport, _cropId, taskType) {
  const listPath = '/api/v1/masters/agricultural_tasks';
  const listRes = await transport.get(listPath);
  const rows = listRes.ok ? parseRows(await listRes.json()) : [];
  const existing = rows.find((row) => row['task_type'] === taskType);
  if (existing?.['id'] != null) {
    return Number(existing['id']);
  }

  const postRes = await transport.post(listPath, {
    agricultural_task: {
      name: `${PLAN_CREATE_READY_PREFIX} ${taskType}`,
      description: 'E2E plan create readiness baseline',
      time_per_sqm: 0.5,
      task_type: taskType,
    },
  });
  if (postRes.ok) {
    const created = /** @type {Record<string, unknown>} */ (await postRes.json());
    if (created['id'] != null) {
      return Number(created['id']);
    }
  }

  const afterRes = await transport.get(listPath);
  const after = afterRes.ok ? parseRows(await afterRes.json()) : [];
  const found = after.find((row) => row['task_type'] === taskType);
  if (found?.['id'] != null) {
    return Number(found['id']);
  }

  const body = await postRes.text();
  throw new Error(`POST agricultural_tasks (${taskType}) failed (${postRes.status}): ${body.slice(0, 300)}`);
}

/**
 * @param {ApiTransport} transport
 * @param {number} cropId
 * @param {number} stageId
 * @param {string} stageName
 */
async function ensureStageRequirements(transport, cropId, stageId, stageName) {
  const tempPath = `/api/v1/masters/crops/${cropId}/crop_stages/${stageId}/temperature_requirement`;
  const tempGet = await transport.get(tempPath);
  if (tempGet.status === 404) {
    const tempPost = await transport.post(tempPath, {
      temperature_requirement: {
        base_temperature: 10,
        optimal_min: 18,
        optimal_max: 28,
        max_temperature: 35,
      },
    });
    if (!tempPost.ok && tempPost.status !== 422) {
      const body = await tempPost.text();
      throw new Error(`POST temperature_requirement failed (${tempPost.status}): ${body.slice(0, 300)}`);
    }
  }

  const thermalPath = `/api/v1/masters/crops/${cropId}/crop_stages/${stageId}/thermal_requirement`;
  const thermalGet = await transport.get(thermalPath);
  if (thermalGet.status === 404) {
    const thermalPost = await transport.post(thermalPath, {
      thermal_requirement: { required_gdd: 200 },
    });
    if (!thermalPost.ok && thermalPost.status !== 422) {
      const body = await thermalPost.text();
      throw new Error(`POST thermal_requirement failed (${thermalPost.status}): ${body.slice(0, 300)}`);
    }
  }
}

/**
 * @param {ApiTransport} transport
 * @param {number} cropId
 * @param {number} stageOrder
 * @param {string} stageName
 * @param {number} agriculturalTaskId
 * @param {string} taskType
 */
async function ensureBlueprint(
  transport,
  cropId,
  stageOrder,
  stageName,
  agriculturalTaskId,
  taskType,
) {
  const listPath = `/api/v1/masters/crops/${cropId}/task_schedule_blueprints`;
  const listRes = await transport.get(listPath);
  const rows = listRes.ok ? parseRows(await listRes.json()) : [];
  const exists = rows.some((row) => row['task_type'] === taskType);
  if (exists) return;

  const postRes = await transport.post(listPath, {
    agricultural_task_id: agriculturalTaskId,
    stage_order: stageOrder,
    stage_name: stageName,
    gdd_trigger: 0,
    task_type: taskType,
    priority: 1,
  });
  if (!postRes.ok) {
    const body = await postRes.text();
    throw new Error(`POST task_schedule_blueprints (${taskType}) failed (${postRes.status}): ${body.slice(0, 300)}`);
  }
}

/**
 * Ensure crop satisfies private plan create readiness (stages + blueprints).
 *
 * @param {ApiTransport} transport
 * @param {number} cropId
 */
export async function ensureCropPlanCreateReady(transport, cropId) {
  const stagesPath = `/api/v1/masters/crops/${cropId}/crop_stages`;
  const stagesRes = await transport.get(stagesPath);
  if (!stagesRes.ok) {
    const body = await stagesRes.text();
    throw new Error(`GET crop_stages failed (${stagesRes.status}): ${body.slice(0, 300)}`);
  }
  let stages = parseRows(await stagesRes.json());
  if (stages.length === 0) {
    const createStageRes = await transport.post(stagesPath, {
      crop_stage: { name: 'Vegetative', order: 1 },
    });
    if (!createStageRes.ok) {
      const body = await createStageRes.text();
      throw new Error(`POST crop_stage failed (${createStageRes.status}): ${body.slice(0, 300)}`);
    }
    const refresh = await transport.get(stagesPath);
    stages = refresh.ok ? parseRows(await refresh.json()) : [];
  }
  const stage = stages[0];
  const stageId = stage?.['id'];
  const stageName = typeof stage?.['name'] === 'string' ? stage['name'] : 'Vegetative';
  const stageOrder = typeof stage?.['order'] === 'number' ? stage['order'] : 1;
  if (stageId == null) {
    throw new Error(`cannot ensure plan create ready crop: missing stage id (cropId=${cropId})`);
  }

  await ensureStageRequirements(transport, cropId, Number(stageId), stageName);

  const fieldWorkTaskId = await ensureAgriculturalTaskByType(transport, cropId, 'field_work');
  const basalTaskId = await ensureAgriculturalTaskByType(transport, cropId, 'basal_fertilization');

  await ensureBlueprint(transport, cropId, stageOrder, stageName, fieldWorkTaskId, 'field_work');
  await ensureBlueprint(transport, cropId, stageOrder, stageName, basalTaskId, 'basal_fertilization');
}

/**
 * @param {ApiTransport} transport
 * @param {number | null} farmId
 * @param {number | null} cropId
 */
export async function ensurePlanCreateReadiness(transport, farmId, cropId) {
  if (farmId != null) {
    await pollFarmWeatherCompleted(transport, farmId);
  }
  if (cropId != null) {
    await ensureCropPlanCreateReady(transport, cropId);
  }
}
