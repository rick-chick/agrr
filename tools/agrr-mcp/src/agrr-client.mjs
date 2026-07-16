const DEFAULT_BASE_URL = 'http://127.0.0.1:3000';

export class AgrrClient {
  /**
   * @param {{ baseUrl?: string, apiKey?: string, fetch?: typeof fetch }} options
   */
  constructor(options = {}) {
    const apiKey = options.apiKey ?? process.env.AGRR_API_KEY ?? '';
    if (!apiKey.trim()) {
      throw new Error('AGRR_API_KEY is required');
    }

    this.baseUrl = (options.baseUrl ?? process.env.AGRR_API_BASE_URL ?? DEFAULT_BASE_URL).replace(
      /\/$/,
      '',
    );
    this.apiKey = apiKey.trim();
    this.fetch = options.fetch ?? globalThis.fetch;
  }

  /** @param {{ region?: string }} [filters] */
  async listReferenceCrops(filters = {}) {
    const crops = await this.#request('GET', '/api/v1/masters/crops');
    if (!Array.isArray(crops)) {
      throw new Error('Expected crops array from masters API');
    }

    return crops.filter((crop) => {
      if (!crop?.is_reference) {
        return false;
      }
      if (filters.region && crop.region !== filters.region) {
        return false;
      }
      return true;
    });
  }

  /** @param {number} cropId */
  async getCropDetail(cropId) {
    return this.#request('GET', `/api/v1/masters/crops/${cropId}`);
  }

  /** @param {number} cropId @param {object} proposal */
  async proposeCropSetup(cropId, proposal) {
    return this.#request(
      'POST',
      `/api/v1/masters/crops/${cropId}/setup_proposal?mode=dry_run`,
      proposal,
    );
  }

  /** @param {number} cropId @param {object} proposal */
  async applyCropSetup(cropId, proposal) {
    return this.#request(
      'POST',
      `/api/v1/masters/crops/${cropId}/setup_proposal?mode=apply`,
      proposal,
    );
  }

  /** @param {'GET'|'POST'} method @param {string} path @param {object} [body] */
  async #request(method, path, body) {
    const url = `${this.baseUrl}${path}`;
    const init = {
      method,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        Accept: 'application/json',
      },
    };

    if (body !== undefined) {
      init.headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(body);
    }

    const response = await this.fetch(url, init);
    const text = await response.text();
    let payload;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = text;
    }

    if (!response.ok) {
      const err = new Error(
        typeof payload === 'object' && payload?.error
          ? String(payload.error)
          : `AGRR API ${response.status} for ${path}`,
      );
      err.status = response.status;
      err.body = payload;
      throw err;
    }

    return payload;
  }
}

export function createAgrrClientFromEnv() {
  return new AgrrClient({
    baseUrl: process.env.AGRR_API_BASE_URL,
    apiKey: process.env.AGRR_API_KEY,
  });
}
