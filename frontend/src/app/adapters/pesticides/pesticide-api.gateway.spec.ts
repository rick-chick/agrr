import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PesticideApiGateway } from './pesticide-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pesticide } from '../../domain/pesticides/pesticide';

describe('PesticideApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
  };
  let gateway: PesticideApiGateway;

  beforeEach(() => {
    client = { get: vi.fn() };
    gateway = new PesticideApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const pesticides: Pesticide[] = [
      { id: 1, name: 'Spray', crop_id: 1, pest_id: 1, is_reference: false }
    ];
    vi.mocked(client.get).mockReturnValue(of(pesticides));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(pesticides);
    expect(client.get).toHaveBeenCalledWith('/pesticides');
  });

  it('show maps crop_name and pest_name from API response', async () => {
    const pesticide: Pesticide = {
      id: 1,
      name: 'Spray',
      crop_id: 51,
      pest_id: 54,
      is_reference: false,
      crop_name: 'Tomato',
      pest_name: 'Aphid'
    };
    vi.mocked(client.get).mockReturnValue(of(pesticide));

    const result = await firstValueFrom(gateway.show(1));
    expect(result.crop_name).toBe('Tomato');
    expect(result.pest_name).toBe('Aphid');
    expect(client.get).toHaveBeenCalledWith('/pesticides/1');
  });

});
