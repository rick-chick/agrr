import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  AgriculturalTaskListView,
  AgriculturalTaskListViewState
} from './agricultural-task-list.view';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { AgriculturalTaskListPresenter } from '../../../adapters/agricultural-tasks/agricultural-task-list.presenter';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { AGRICULTURAL_TASK_GATEWAY } from '../../../usecase/agricultural-tasks/agricultural-task-gateway';
import { AgriculturalTaskApiGateway } from '../../../adapters/agricultural-tasks/agricultural-task-api.gateway';

const initialControl: AgriculturalTaskListViewState = {
  loading: true,
  error: null,
  tasks: []
};

@Component({
  selector: 'app-agricultural-task-list',
  standalone: true,
  imports: [CommonModule],
  providers: [
    AgriculturalTaskListPresenter,
    LoadAgriculturalTaskListUseCase,
    {
      provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT,
      useExisting: AgriculturalTaskListPresenter
    },
    { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
  ],
  template: `
    <section class="page">
      <h2>Agricultural Tasks</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let item of control.tasks">{{ item.name }}</li>
        </ul>
      }
    </section>
  `,
  styleUrl: './agricultural-task-list.component.css'
})
export class AgriculturalTaskListComponent implements AgriculturalTaskListView, OnInit {
  private readonly useCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly presenter = inject(AgriculturalTaskListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: AgriculturalTaskListViewState = initialControl;
  get control(): AgriculturalTaskListViewState {
    return this._control;
  }
  set control(value: AgriculturalTaskListViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute();
  }
}
