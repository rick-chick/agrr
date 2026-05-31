import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PesticideApiGateway } from './pesticide-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pesticide } from '../../domain/pesticides/pesticide';

describe('PesticideApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    deleteWithUndo: ReturnType<typeof vi.fn>;
  };
  let gateway: PesticideApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), deleteWithUndo: vi.fn() };
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

  it('destroy uses deleteWithUndo on masters API path', async () => {
    vi.mocked(client.deleteWithUndo).mockReturnValue(
      of({ undo_token: 'token-1', undo_path: '/undo_deletion?undo_token=token-1', toast_message: 'deleted' })
    );

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.deleteWithUndo).toHaveBeenCalledWith('/pesticides/42');
    expect(result?.undo_token).toBe('token-1');
  });
});
