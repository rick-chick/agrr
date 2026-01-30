import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PesticideListView, PesticideListViewState } from './pesticide-list.view';
import { LoadPesticideListUseCase } from '../../../usecase/pesticides/load-pesticide-list.usecase';
import { PesticideListPresenter } from '../../../adapters/pesticides/pesticide-list.presenter';
import { LOAD_PESTICIDE_LIST_OUTPUT_PORT } from '../../../usecase/pesticides/load-pesticide-list.output-port';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { PesticideApiGateway } from '../../../adapters/pesticides/pesticide-api.gateway';

const initialControl: PesticideListViewState = {
  loading: true,
  error: null,
  pesticides: []
};

@Component({
  selector: 'app-pesticide-list',
  standalone: true,
  imports: [CommonModule],
  providers: [
    PesticideListPresenter,
    LoadPesticideListUseCase,
    { provide: LOAD_PESTICIDE_LIST_OUTPUT_PORT, useExisting: PesticideListPresenter },
    { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway }
  ],
  template: `
    <section class="page">
      <h2>Pesticides</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let item of control.pesticides">{{ item.name }}</li>
        </ul>
      }
    </section>
  `,
  styleUrl: './pesticide-list.component.css'
})
export class PesticideListComponent implements PesticideListView, OnInit {
  private readonly useCase = inject(LoadPesticideListUseCase);
  private readonly presenter = inject(PesticideListPresenter);

  private _control: PesticideListViewState = initialControl;
  get control(): PesticideListViewState {
    return this._control;
  }
  set control(value: PesticideListViewState) {
    this._control = value;
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
