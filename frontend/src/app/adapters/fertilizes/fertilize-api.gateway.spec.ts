import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { FertilizeApiGateway } from './fertilize-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Fertilize } from '../../domain/fertilizes/fertilize';

describe('FertilizeApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
  };
  let gateway: FertilizeApiGateway;

  beforeEach(() => {
    client = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn()
    };
    gateway = new FertilizeApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const fertilizes: Fertilize[] = [{ id: 1, name: 'NPK', is_reference: false }];
    vi.mocked(client.get).mockReturnValue(of(fertilizes));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(fertilizes);
    expect(client.get).toHaveBeenCalledWith('/fertilizes');
  });

});
