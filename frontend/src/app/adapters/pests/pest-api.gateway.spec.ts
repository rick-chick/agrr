import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PestApiGateway } from './pest-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pest } from '../../domain/pests/pest';

describe('PestApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
  };
  let gateway: PestApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), post: vi.fn(), patch: vi.fn() };
    gateway = new PestApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const pests: Pest[] = [{ id: 1, name: 'Aphid', is_reference: false }];
    vi.mocked(client.get).mockReturnValue(of(pests));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(pests);
    expect(client.get).toHaveBeenCalledWith('/pests');
  });

  it('show expects flat Pest JSON from masters API', async () => {
    const pest: Pest = {
      id: 9,
      name: 'Aphid',
      name_scientific: 'Aphidoidea',
      family: 'Aphididae',
      is_reference: false
    };
    vi.mocked(client.get).mockReturnValue(of(pest));

    const result = await firstValueFrom(gateway.show(9));
    expect(result.name).toBe('Aphid');
    expect(result.name_scientific).toBe('Aphidoidea');
    expect(client.get).toHaveBeenCalledWith('/pests/9');
  });

  it('create wraps payload in pest key', async () => {
    const created: Pest = { id: 2, name: 'New pest', is_reference: false };
    vi.mocked(client.post).mockReturnValue(of(created));

    const result = await firstValueFrom(
      gateway.create({
        name: 'New pest',
        name_scientific: 'Species',
        family: 'Family',
        order: null,
        description: null,
        occurrence_season: null,
        region: null
      })
    );
    expect(result).toEqual(created);
    expect(client.post).toHaveBeenCalledWith('/pests', {
      pest: {
        name: 'New pest',
        name_scientific: 'Species',
        family: 'Family',
        order: null,
        description: null,
        occurrence_season: null,
        region: null
      }
    });
  });

});
