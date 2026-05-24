import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CropApiGateway } from './crop-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Crop } from '../../domain/crops/crop';
import { CropDeleteResponse } from '../../usecase/crops/crop-gateway';

describe('CropApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: CropApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), delete: vi.fn() };
    gateway = new CropApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const crops: Crop[] = [{ id: 1, name: 'Tomato', is_reference: false, groups: [] }];
    vi.mocked(client.get).mockReturnValue(of(crops));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(crops);
    expect(client.get).toHaveBeenCalledWith('/crops');
  });

  it('destroy uses masters API relative path', async () => {
    const deleteResponse: CropDeleteResponse = {
      undo: {
        undo_token: 'token-1',
        undo_path: '/undo',
        toast_message: 'deleted',
        undo_deadline: '2026-01-01T00:00:00Z',
        auto_hide_after: 5
      }
    };
    vi.mocked(client.delete).mockReturnValue(of(deleteResponse));

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.delete).toHaveBeenCalledWith('/crops/42');
    expect(result.undo?.undo_token).toBe('token-1');
  });
});
