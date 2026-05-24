import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { AgriculturalTaskApiGateway } from './agricultural-task-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

describe('AgriculturalTaskApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: AgriculturalTaskApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), delete: vi.fn() };
    gateway = new AgriculturalTaskApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const tasks: AgriculturalTask[] = [
      { id: 1, name: 'Weeding', required_tools: [], is_reference: false }
    ];
    vi.mocked(client.get).mockReturnValue(of(tasks));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(tasks);
    expect(client.get).toHaveBeenCalledWith('/agricultural_tasks');
  });

  it('destroy uses masters API relative path and maps undo response', async () => {
    vi.mocked(client.delete).mockReturnValue(
      of({ undo_token: 'token-1', undo_path: '/undo', toast_message: 'deleted' })
    );

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.delete).toHaveBeenCalledWith('/agricultural_tasks/42');
    expect(result.undo?.undo_token).toBe('token-1');
  });
});
