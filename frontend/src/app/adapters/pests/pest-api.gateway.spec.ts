import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PestApiGateway } from './pest-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pest } from '../../domain/pests/pest';

describe('PestApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: PestApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), delete: vi.fn() };
    gateway = new PestApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const pests: Pest[] = [{ id: 1, name: 'Aphid', is_reference: false }];
    vi.mocked(client.get).mockReturnValue(of(pests));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(pests);
    expect(client.get).toHaveBeenCalledWith('/pests');
  });

  it('destroy uses masters API relative path and maps undo response', async () => {
    vi.mocked(client.delete).mockReturnValue(
      of({ undo_token: 'token-1', undo_path: '/undo', toast_message: 'deleted' })
    );

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.delete).toHaveBeenCalledWith('/pests/42');
    expect(result.undo?.undo_token).toBe('token-1');
  });
});
