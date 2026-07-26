import { InjectionToken, Type } from '@angular/core';
import type { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';

export type HomeDemoGanttShellLoader = () => Promise<Type<PlanGanttClimateShellComponent>>;

/** Lazy-loads the shared gantt + climate shell for the home demo (separate chunk). */
export async function loadHomeDemoGanttShell(): Promise<Type<PlanGanttClimateShellComponent>> {
  const module = await import('../plans/plan-gantt-climate-shell.component');
  return module.PlanGanttClimateShellComponent;
}

export const LOAD_HOME_DEMO_GANTT_SHELL = new InjectionToken<HomeDemoGanttShellLoader>(
  'LOAD_HOME_DEMO_GANTT_SHELL',
  {
    providedIn: 'root',
    factory: () => loadHomeDemoGanttShell
  }
);
