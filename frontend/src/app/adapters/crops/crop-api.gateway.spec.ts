import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CropApiGateway } from './crop-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Crop } from '../../domain/crops/crop';

describe('CropApiGateway', () => {
  let client: { get: ReturnType<typeof vi.fn> };
  let gateway: CropApiGateway;

  beforeEach(() => {
    client = { get: vi.fn() };
    gateway = new CropApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const crops: Crop[] = [{ id: 1, name: 'Tomato', is_reference: false, groups: [] }];
    vi.mocked(client.get).mockReturnValue(of(crops));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(crops);
    expect(client.get).toHaveBeenCalledWith('/crops');
  });

});
