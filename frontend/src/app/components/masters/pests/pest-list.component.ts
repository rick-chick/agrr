import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PestListView, PestListViewState } from './pest-list.view';
import { LoadPestListUseCase } from '../../../usecase/pests/load-pest-list.usecase';
import { PestListPresenter } from '../../../adapters/pests/pest-list.presenter';
import { LOAD_PEST_LIST_OUTPUT_PORT } from '../../../usecase/pests/load-pest-list.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialControl: PestListViewState = {
  loading: true,
  error: null,
  pests: []
};

@Component({
  selector: 'app-pest-list',
  standalone: true,
  imports: [CommonModule],
  providers: [
    PestListPresenter,
    LoadPestListUseCase,
    { provide: LOAD_PEST_LIST_OUTPUT_PORT, useExisting: PestListPresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <section class="page">
      <h2>Pests</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let item of control.pests">{{ item.name }}</li>
        </ul>
      }
    </section>
  `,
  styleUrl: './pest-list.component.css'
})
export class PestListComponent implements PestListView, OnInit {
  private readonly useCase = inject(LoadPestListUseCase);
  private readonly presenter = inject(PestListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestListViewState = initialControl;
  get control(): PestListViewState {
    return this._control;
  }
  set control(value: PestListViewState) {
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
