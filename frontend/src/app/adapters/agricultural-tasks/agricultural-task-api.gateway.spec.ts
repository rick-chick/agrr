import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { AgriculturalTaskApiGateway } from './agricultural-task-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

describe('AgriculturalTaskApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    deleteWithUndo: ReturnType<typeof vi.fn>;
  };
  let gateway: AgriculturalTaskApiGateway;

  beforeEach(() => {
    client = { get: vi.fn(), deleteWithUndo: vi.fn() };
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

  it('destroy uses deleteWithUndo on masters API path', async () => {
    vi.mocked(client.deleteWithUndo).mockReturnValue(
      of({ undo_token: 'token-1', undo_path: '/undo_deletion?undo_token=token-1', toast_message: 'deleted' })
    );

    const result = await firstValueFrom(gateway.destroy(42));
    expect(client.deleteWithUndo).toHaveBeenCalledWith('/agricultural_tasks/42');
    expect(result?.undo_token).toBe('token-1');
  });
});
