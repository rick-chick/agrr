import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { FieldClimateApiGateway } from './field-climate-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';

describe('FieldClimateApiGateway', () => {
  let apiClient: {
    get: ReturnType<typeof vi.fn>;
  };
  let gateway: FieldClimateApiGateway;

  const climateData: FieldCultivationClimateData = {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'Field A',
      crop_name: 'Crop A',
      start_date: '2025-01-01',
      completion_date: '2025-02-01'
    },
    farm: {
      id: 10,
      name: 'Farm A',
      latitude: 35.0,
      longitude: 139.0
    },
    crop_requirements: {
      base_temperature: 5
    },
    weather_data: [],
    gdd_data: [],
    stages: [],
    progress_result: {},
    debug_info: {}
  };

  beforeEach(() => {
    apiClient = {
      get: vi.fn()
    };
    gateway = new FieldClimateApiGateway(
      apiClient as unknown as ApiClientService
    );
  });

  it('fetches private climate data with the plans path', async () => {
    vi.mocked(apiClient.get).mockReturnValue(of(climateData));

    const result = await firstValueFrom(
      gateway.fetchFieldClimateData({
        fieldCultivationId: 123,
        planType: 'private'
      })
    );

    expect(result).toEqual(climateData);
    expect(apiClient.get).toHaveBeenCalledWith(
      '/api/v1/plans/field_cultivations/123/climate_data'
    );
  });

  it('fetches public climate data with the public plans path', async () => {
    vi.mocked(apiClient.get).mockReturnValue(of(climateData));

    const result = await firstValueFrom(
      gateway.fetchFieldClimateData({
        fieldCultivationId: 456,
        planType: 'public'
      })
    );

    expect(result).toEqual(climateData);
    expect(apiClient.get).toHaveBeenCalledWith(
      '/api/v1/public_plans/field_cultivations/456/climate_data'
    );
  });
});
