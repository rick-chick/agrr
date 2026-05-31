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

});
