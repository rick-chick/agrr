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
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: FertilizeApiGateway;

  beforeEach(() => {
    client = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    };
    gateway = new FertilizeApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const fertilizes: Fertilize[] = [{ id: 1, name: 'NPK' }];
    vi.mocked(client.get).mockReturnValue(of(fertilizes));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(fertilizes);
    expect(client.get).toHaveBeenCalledWith('/fertilizes');
  });

  it('destroy uses masters API relative path and maps undo response', async () => {
    vi.mocked(client.delete).mockReturnValue(
      of({
        undo_token: 'token-1',
        undo_path: '/undo_deletion?undo_token=token-1',
        toast_message: 'deleted'
      })
    );

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.delete).toHaveBeenCalledWith('/fertilizes/42');
    expect(result.undo?.undo_token).toBe('token-1');
  });
});
