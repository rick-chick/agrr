import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Crop } from '../../domain/crops/crop';
import type { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import type { Farm } from '../../domain/farms/farm';
import { LoadPlanNewReadinessUseCase } from './load-plan-new-readiness.usecase';
import type { CropGateway } from '../crops/crop-gateway';
import type { CropTaskScheduleBlueprintGateway } from '../crops/crop-task-schedule-blueprint-gateway';
import type { PrivatePlanCreateGateway } from '../private-plan-create/private-plan-create-gateway';

const farm: Farm = {
  id: 1,
  name: 'North Farm',
  latitude: 35,
  longitude: 139,
  region: null,
  weather_data_status: 'completed',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z'
};

const userCrop: Crop = {
  id: 1,
  name: 'Tomato',
  is_reference: false,
  groups: [],
  crop_stages: [
    {
      id: 10,
      crop_id: 1,
      name: 'Vegetative',
      order: 1,
      temperature_requirement: { id: 1, crop_stage_id: 10, base_temperature: 10 },
      thermal_requirement: { id: 1, crop_stage_id: 10, required_gdd: 100 }
    }
  ]
};

const referenceCrop: Crop = {
  id: 99,
  name: 'Reference Tomato',
  is_reference: true,
  groups: []
};

const readyBlueprints: CropTaskScheduleBlueprint[] = [
  {
    id: 1,
    crop_id: 1,
    agricultural_task_id: 5,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Vegetative',
    gdd_trigger: 100,
    gdd_tolerance: null,
    task_type: 'field_work',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    name: 'Weeding',
    agricultural_task: { id: 5, name: 'Weeding' }
  },
  {
    id: 2,
    crop_id: 1,
    agricultural_task_id: 6,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Vegetative',
    gdd_trigger: 100,
    gdd_tolerance: null,
    task_type: 'basal_fertilization',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    name: 'Basal',
    agricultural_task: { id: 6, name: 'Basal' }
  }
];

describe('LoadPlanNewReadinessUseCase', () => {
  let planCreateGateway: PrivatePlanCreateGateway;
  let cropGateway: CropGateway;
  let blueprintGateway: CropTaskScheduleBlueprintGateway;
  let useCase: LoadPlanNewReadinessUseCase;

  beforeEach(() => {
    planCreateGateway = {
      fetchFarm: vi.fn(() => of({ farm, totalArea: 100 })),
      fetchCrops: vi.fn(() => of([userCrop, referenceCrop])),
      fetchFarms: vi.fn(),
      fetchFarmsForPlanCreate: vi.fn(),
      createPlan: vi.fn()
    };

    cropGateway = {
      show: vi.fn((_cropId: number) => of(userCrop)),
      list: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      destroy: vi.fn()
    };

    blueprintGateway = {
      list: vi.fn(() => of(readyBlueprints)),
      create: vi.fn(),
      regenerate: vi.fn(),
      update: vi.fn(),
      destroy: vi.fn()
    };

    useCase = new LoadPlanNewReadinessUseCase(
      planCreateGateway,
      cropGateway,
      blueprintGateway
    );
  });

  it('builds readiness from farm weather, user crops, and blueprints', () => {
    let result: ReturnType<typeof useCase.execute> extends infer O ? O extends { subscribe: (fn: (v: infer V) => void) => void } ? V : never : never;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!).toMatchObject({
      farmId: 1,
      fieldCount: 2,
      fieldsReady: true,
      weatherReady: true,
      cropsReady: true,
      allReady: true
    });
    expect(result!.cropSummaries).toHaveLength(1);
    expect(result!.cropSummaries[0]).toMatchObject({ cropId: 1, name: 'Tomato', ready: true });
    expect(cropGateway.show).toHaveBeenCalledWith(1);
    expect(blueprintGateway.list).toHaveBeenCalledWith(1);
  });

  it('returns empty crop readiness when only reference crops exist', () => {
    vi.mocked(planCreateGateway.fetchCrops).mockReturnValue(of([referenceCrop]));

    let result: { cropsReady: boolean; cropSummaries: unknown[] } | undefined;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!.cropsReady).toBe(false);
    expect(result!.cropSummaries).toEqual([]);
    expect(cropGateway.show).not.toHaveBeenCalled();
    expect(blueprintGateway.list).not.toHaveBeenCalled();
  });

  it('degrades gracefully when farm fetch fails', () => {
    vi.mocked(planCreateGateway.fetchFarm).mockReturnValue(throwError(() => new Error('network')));

    let result: { weatherReady: boolean; weatherStatus: Farm['weather_data_status'] } | undefined;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!.weatherReady).toBe(false);
    expect(result!.weatherStatus).toBeUndefined();
  });

  it('degrades gracefully when crops fetch fails', () => {
    vi.mocked(planCreateGateway.fetchCrops).mockReturnValue(throwError(() => new Error('network')));

    let result: { cropsReady: boolean; cropSummaries: unknown[] } | undefined;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!.cropsReady).toBe(false);
    expect(result!.cropSummaries).toEqual([]);
  });

  it('falls back to list crop when crop detail fetch fails', () => {
    vi.mocked(cropGateway.show).mockReturnValue(throwError(() => new Error('network')));

    let result: { cropSummaries: Array<{ cropId: number; ready: boolean }> } | undefined;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!.cropSummaries).toHaveLength(1);
    expect(result!.cropSummaries[0].cropId).toBe(1);
    expect(result!.cropSummaries[0].ready).toBe(true);
  });

  it('treats missing blueprints as not ready when blueprint fetch fails', () => {
    vi.mocked(blueprintGateway.list).mockReturnValue(throwError(() => new Error('network')));

    let result: { cropsReady: boolean; cropSummaries: Array<{ ready: boolean }> } | undefined;
    useCase.execute(1, 2, true).subscribe((readiness) => {
      result = readiness;
    });

    expect(result!.cropsReady).toBe(false);
    expect(result!.cropSummaries[0].ready).toBe(false);
  });
});
