import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { FarmApiGateway } from './farm-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Farm } from '../../domain/farms/farm';
import { Field } from '../../domain/farms/field';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('FarmApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: FarmApiGateway;

  beforeEach(() => {
    client = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    };
    gateway = new FarmApiGateway(client as unknown as MastersClientService);
  });

  describe('list', () => {
    it('returns Observable<Farm[]>', async () => {
      const farms: Farm[] = [
        { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' },
        { id: 2, name: 'Farm 2', latitude: 36.0, longitude: 136.0, region: 'Region 2' }
      ];
      vi.mocked(client.get).mockReturnValue(of(farms));

      const result = await firstValueFrom(gateway.list());
      expect(result).toEqual(farms);
      expect(client.get).toHaveBeenCalledWith('/farms');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.list())).rejects.toThrow('network error');
    });
  });

  describe('show', () => {
    it('returns Observable<Farm>', async () => {
      const farm: Farm = { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' };
      vi.mocked(client.get).mockReturnValue(of(farm));

      const result = await firstValueFrom(gateway.show(1));
      expect(result).toEqual(farm);
      expect(client.get).toHaveBeenCalledWith('/farms/1');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.show(1))).rejects.toThrow('network error');
    });
  });

  describe('listFieldsByFarm', () => {
    it('returns Observable<Field[]>', async () => {
      const fields: Field[] = [
        { id: 1, farm_id: 1, user_id: null, name: 'Field 1', description: null, area: 100, daily_fixed_cost: 50, region: 'Region 1', created_at: '2023-01-01', updated_at: '2023-01-01' },
        { id: 2, farm_id: 1, user_id: null, name: 'Field 2', description: null, area: 200, daily_fixed_cost: 100, region: 'Region 1', created_at: '2023-01-01', updated_at: '2023-01-01' }
      ];
      vi.mocked(client.get).mockReturnValue(of(fields));

      const result = await firstValueFrom(gateway.listFieldsByFarm(1));
      expect(result).toEqual(fields);
      expect(client.get).toHaveBeenCalledWith('/farms/1/fields');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.listFieldsByFarm(1))).rejects.toThrow('network error');
    });
  });

  describe('create', () => {
    it('returns Observable<Farm>', async () => {
      const payload = { name: 'New Farm', region: 'Region 1', latitude: 35.0, longitude: 135.0 };
      const farm: Farm = { id: 3, ...payload };
      vi.mocked(client.post).mockReturnValue(of(farm));

      const result = await firstValueFrom(gateway.create(payload));
      expect(result).toEqual(farm);
      expect(client.post).toHaveBeenCalledWith('/farms', { farm: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'New Farm', region: 'Region 1', latitude: 35.0, longitude: 135.0 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.create(payload))).rejects.toThrow('network error');
    });
  });

  describe('update', () => {
    it('returns Observable<Farm>', async () => {
      const payload = { name: 'Updated Farm', region: 'Region 1', latitude: 35.0, longitude: 135.0 };
      const farm: Farm = { id: 1, ...payload };
      vi.mocked(client.patch).mockReturnValue(of(farm));

      const result = await firstValueFrom(gateway.update(1, payload));
      expect(result).toEqual(farm);
      expect(client.patch).toHaveBeenCalledWith('/farms/1', { farm: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'Updated Farm', region: 'Region 1', latitude: 35.0, longitude: 135.0 };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.update(1, payload))).rejects.toThrow('network error');
    });
  });

  describe('destroy', () => {
    it('returns Observable<DeletionUndoResponse>', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'token123',
        toast_message: 'Farm deleted',
        undo_path: '/api/v1/farms/undo'
      };
      vi.mocked(client.delete).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.destroy(1));
      expect(result).toEqual(response);
      expect(client.delete).toHaveBeenCalledWith('/farms/1');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.destroy(1))).rejects.toThrow('network error');
    });
  });

  describe('createField', () => {
    it('returns Observable<Field>', async () => {
      const payload = { name: 'New Field', area: 100, daily_fixed_cost: 50, region: 'Region 1' };
      const field: Field = {
        id: 3,
        farm_id: 1,
        user_id: null,
        ...payload,
        description: null,
        created_at: '2023-01-01',
        updated_at: '2023-01-01'
      };
      vi.mocked(client.post).mockReturnValue(of(field));

      const result = await firstValueFrom(gateway.createField(1, payload));
      expect(result).toEqual(field);
      expect(client.post).toHaveBeenCalledWith('/farms/1/fields', { field: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'New Field', area: 100, daily_fixed_cost: 50, region: 'Region 1' };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createField(1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateField', () => {
    it('returns Observable<Field>', async () => {
      const payload = { name: 'Updated Field', area: 150, daily_fixed_cost: 75, region: 'Region 1' };
      const field: Field = {
        id: 1,
        farm_id: 1,
        user_id: null,
        ...payload,
        description: null,
        created_at: '2023-01-01',
        updated_at: '2023-01-02'
      };
      vi.mocked(client.patch).mockReturnValue(of(field));

      const result = await firstValueFrom(gateway.updateField(1, payload));
      expect(result).toEqual(field);
      expect(client.patch).toHaveBeenCalledWith('/fields/1', { field: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'Updated Field', area: 150, daily_fixed_cost: 75, region: 'Region 1' };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateField(1, payload))).rejects.toThrow('network error');
    });
  });

  describe('destroyField', () => {
    it('returns Observable<DeletionUndoResponse>', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'token456',
        toast_message: 'Field deleted',
        undo_path: '/api/v1/fields/undo'
      };
      vi.mocked(client.delete).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.destroyField(1));
      expect(result).toEqual(response);
      expect(client.delete).toHaveBeenCalledWith('/fields/1');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.destroyField(1))).rejects.toThrow('network error');
    });
  });
});