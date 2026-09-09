import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { AgriculturalTaskListComponent } from './agricultural-task-list.component';
import { AgriculturalTaskListPresenter } from '../../../usecase/agricultural-tasks/agricultural-task-list.providers';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { UndoToastService } from '../../../services/undo-toast.service';
import { ListRefreshBus } from '../../../core/list-refresh/list-refresh-bus.service';
import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';

const taskWithSkillLevel: AgriculturalTask = {
  id: 1,
  name: 'Weeding',
  description: null,
  skill_level: 'beginner',
  required_tools: [],
  is_reference: false
};

const taskWithoutSkillLevel: AgriculturalTask = {
  id: 2,
  name: 'Harvesting',
  description: null,
  skill_level: null,
  required_tools: [],
  is_reference: false
};

describe('AgriculturalTaskListComponent uniform card rows', () => {
  let fixture: ComponentFixture<AgriculturalTaskListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AgriculturalTaskListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadAgriculturalTaskListUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteAgriculturalTaskUseCase, useValue: { execute: vi.fn() } },
        { provide: AgriculturalTaskListPresenter, useValue: { setView: vi.fn() } },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        { provide: UndoToastService, useValue: { show: vi.fn() } },
        { provide: ListRefreshBus, useValue: { onRefresh: () => () => undefined } }
      ]
    })
      .overrideComponent(AgriculturalTaskListComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(AgriculturalTaskListComponent);
    fixture.detectChanges();
  });

  function renderTasks(tasks: AgriculturalTask[]): HTMLElement {
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      errorIsWarmup: false,
      tasks,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
    return fixture.nativeElement;
  }

  it('uses uniform card layout with single-line title and skill level row', () => {
    const el = renderTasks([taskWithSkillLevel]);
    const body = el.querySelector('.item-card__body') as HTMLElement;
    const title = el.querySelector('.item-card__title--single-line') as HTMLElement;
    const skillRow = el.querySelector(
      '.agricultural-task-list__skill-level.item-card__meta--single-line'
    ) as HTMLElement;

    expect(body.classList.contains('item-card__body--uniform')).toBe(true);
    expect(title).toBeTruthy();
    expect(skillRow).toBeTruthy();
    expect(skillRow.textContent).toContain('agricultural_tasks.show.skill_level_beginner');
  });

  it('keeps skill level row in DOM when skill_level is absent', () => {
    const el = renderTasks([taskWithoutSkillLevel]);
    const skillRow = el.querySelector('.agricultural-task-list__skill-level') as HTMLElement;
    expect(skillRow).toBeTruthy();
    expect(skillRow.textContent?.trim()).toBe('');
  });
});
