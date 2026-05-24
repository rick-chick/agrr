import { of, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { InteractionRuleApiGateway } from './interaction-rule-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';

describe('InteractionRuleApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: InteractionRuleApiGateway;

  beforeEach(() => {
    client = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    };
    gateway = new InteractionRuleApiGateway(client as unknown as MastersClientService);
  });

  it('list uses masters API relative path', async () => {
    const rules: InteractionRule[] = [
      {
        id: 1,
        rule_type: 'continuous',
        source_group: 'A',
        target_group: 'B',
        impact_ratio: 1,
        is_directional: true
      }
    ];
    vi.mocked(client.get).mockReturnValue(of(rules));

    const result = await firstValueFrom(gateway.list());
    expect(result).toEqual(rules);
    expect(client.get).toHaveBeenCalledWith('/interaction_rules');
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
    expect(client.delete).toHaveBeenCalledWith('/interaction_rules/42');
    expect(result.undo?.undo_token).toBe('token-1');
  });
});
