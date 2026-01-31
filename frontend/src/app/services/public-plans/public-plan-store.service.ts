import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

export interface PublicPlanState {
  farm: Farm | null;
  farmSize: FarmSizeOption | null;
  selectedCrops: Crop[];
  planId: number | null;
}

const INITIAL_STATE: PublicPlanState = {
  farm: null,
  farmSize: null,
  selectedCrops: [],
  planId: null
};

const SESSION_STORAGE_KEY = 'agrr_public_plan_state';

@Injectable({ providedIn: 'root' })
export class PublicPlanStore {
  private stateSubject = new BehaviorSubject<PublicPlanState>(this.loadFromSession());
  public state$: Observable<PublicPlanState> = this.stateSubject.asObservable();

  get state(): PublicPlanState {
    return this.stateSubject.value;
  }

  setFarm(farm: Farm): void {
    this.updateState({ farm, farmSize: null, selectedCrops: [], planId: null });
  }

  setFarmSize(farmSize: FarmSizeOption): void {
    this.updateState({ farmSize });
  }

  setSelectedCrops(crops: Crop[]): void {
    this.updateState({ selectedCrops: crops });
  }

  setPlanId(planId: number): void {
    this.updateState({ planId });
  }

  reset(): void {
    this.updateState(INITIAL_STATE);
    sessionStorage.removeItem(SESSION_STORAGE_KEY);
  }

  private updateState(patch: Partial<PublicPlanState>): void {
    const newState = { ...this.state, ...patch };
    this.stateSubject.next(newState);
    this.saveToSession(newState);
  }

  private saveToSession(state: PublicPlanState): void {
    try {
      sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('Failed to save public plan state to session storage', e);
    }
  }

  private loadFromSession(): PublicPlanState {
    try {
      const stored = sessionStorage.getItem(SESSION_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        // Ensure farm.id is a number (JSON.parse converts it to string)
        if (parsed.farm && typeof parsed.farm.id === 'string') {
          parsed.farm.id = parseInt(parsed.farm.id, 10);
        }
        return parsed;
      }
    } catch (e) {
      console.warn('Failed to load public plan state from session storage', e);
    }
    return INITIAL_STATE;
  }
}
