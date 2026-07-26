import type { Type } from '@angular/core';
import type { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';

/** Lazy-loads the shared gantt + climate shell for the home demo (separate chunk). */
export async function loadHomeDemoGanttShell(): Promise<Type<PlanGanttClimateShellComponent>> {
  const module = await import('../plans/plan-gantt-climate-shell.component');
  return module.PlanGanttClimateShellComponent;
}
