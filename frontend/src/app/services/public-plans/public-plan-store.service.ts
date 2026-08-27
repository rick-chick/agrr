import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';
import { DEFAULT_PUBLIC_PLAN_FARM_SIZE } from '../../domain/public-plans/default-public-plan-farm-size';
import { PublicPlanSessionPort } from '../../usecase/public-plans/public-plan-session.port';

export interface PublicPlanState {
  farm: Farm | null;
  farmSize: FarmSizeOption | null;
  selectedCrops: Crop[];
  planId: number | null;
  /** research GDD レポート等からの作物 slug（select-crop で一度だけ消費） */
  pendingCropSlug: string | null;
  /** entry-schedule 等からの作物 id（select-crop で一度だけ消費） */
  pendingCropId: number | null;
}

const INITIAL_STATE: PublicPlanState = {
  farm: null,
  farmSize: null,
  selectedCrops: [],
  planId: null,
  pendingCropSlug: null,
  pendingCropId: null
};

const SESSION_STORAGE_KEY = 'agrr_public_plan_state';
const SESSION_TOKEN_KEY = 'agrr_public_plan_session_token';

@Injectable({ providedIn: 'root' })
export class PublicPlanStore implements PublicPlanSessionPort {
  private stateSubject = new BehaviorSubject<PublicPlanState>(this.loadFromSession());
  public state$: Observable<PublicPlanState> = this.stateSubject.asObservable();

  get state(): PublicPlanState {
    return this.stateSubject.value;
  }

  setFarm(farm: Farm): void {
    this.updateState({
      farm,
      farmSize: DEFAULT_PUBLIC_PLAN_FARM_SIZE,
      selectedCrops: [],
      planId: null
    });
  }

  setSelectedCrops(crops: Crop[]): void {
    this.updateState({ selectedCrops: crops });
  }

  setPlanId(planId: number): void {
    this.updateState({ planId });
  }

  setPendingCropSlug(slug: string | null): void {
    this.updateState({ pendingCropSlug: slug });
  }

  setPendingCropId(cropId: number | null): void {
    this.updateState({ pendingCropId: cropId });
  }

  reset(): void {
    this.updateState(INITIAL_STATE);
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
      sessionStorage.removeItem(SESSION_TOKEN_KEY);
    }
  }

  ensureSessionToken(): string {
    if (typeof sessionStorage === 'undefined') {
      return this.generateSessionToken();
    }
    const existing = sessionStorage.getItem(SESSION_TOKEN_KEY);
    if (existing && existing.length > 0) {
      return existing;
    }
    const token = this.generateSessionToken();
    sessionStorage.setItem(SESSION_TOKEN_KEY, token);
    return token;
  }

  private generateSessionToken(): string {
    const bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }

  /** E2E シード等で sessionStorage が後から入ったとき、farm 未設定なら再読込する */
  syncFromSessionStorageIfFarmMissing(): void {
    const currentFarm = this.state.farm;
    if (currentFarm && typeof currentFarm.id === 'number' && currentFarm.id > 0) {
      return;
    }
    const fromSession = this.loadFromSession();
    if (!fromSession.farm || typeof fromSession.farm.id !== 'number' || fromSession.farm.id <= 0) {
      return;
    }
    this.stateSubject.next({ ...this.state, ...fromSession });
  }

  private updateState(patch: Partial<PublicPlanState>): void {
    const newState = { ...this.state, ...patch };
    this.stateSubject.next(newState);
    this.saveToSession(newState);
  }

  private saveToSession(state: PublicPlanState): void {
    if (typeof sessionStorage === 'undefined') {
      return;
    }
    try {
      sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('Failed to save public plan state to session storage', e);
    }
  }

  private loadFromSession(): PublicPlanState {
    if (typeof sessionStorage === 'undefined') {
      return INITIAL_STATE;
    }
    try {
      const stored = sessionStorage.getItem(SESSION_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        // Ensure farm.id is a number (JSON.parse converts it to string)
        if (parsed.farm && typeof parsed.farm.id === 'string') {
          parsed.farm.id = parseInt(parsed.farm.id, 10);
        }
        return {
          ...INITIAL_STATE,
          ...parsed,
          pendingCropSlug: parsed.pendingCropSlug ?? null,
          pendingCropId:
            typeof parsed.pendingCropId === 'number' ? parsed.pendingCropId : null
        };
      }
    } catch (e) {
      console.warn('Failed to load public plan state from session storage', e);
    }
    return INITIAL_STATE;
  }
}
