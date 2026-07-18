import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropListStagesPanelComponent } from './crop-list-stages-panel.component';
import {
  CropListStagesPanelPresenter,
  CROP_LIST_STAGES_PANEL_PROVIDERS
} from '../../../usecase/crops/crop-list-stages-panel.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { AuthService } from '../../../services/auth.service';
import { Crop } from '../../../domain/crops/crop';

const referenceCrop: Crop = {
  id: 20,
  name: 'Rice',
  variety: null,
  is_reference: true,
  groups: [],
  crop_stages: [
    {
      id: 1,
      crop_id: 20,
      name: 'Seedling',
      order: 1
    }
  ]
};

describe('CropListStagesPanelComponent', () => {
  let fixture: ComponentFixture<CropListStagesPanelComponent>;
  let presenter: CropListStagesPanelPresenter;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CropListStagesPanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        ...CROP_LIST_STAGES_PANEL_PROVIDERS,
        { provide: LoadCropForEditUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: () => ({ admin: false }) } }
      ]
    })
      .overrideComponent(CropListStagesPanelComponent, { set: { providers: [] } })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          edit: {
            reference_stages_readonly: 'Reference crop stages are read-only.',
            table_order: 'Order',
            table_optimal_range: 'Optimal range',
            value_missing: '—'
          },
          show: {
            celsius_unit: '°C'
          },
          index: {
            inline: {
              stages_full_edit: 'Edit growth stages'
            }
          }
        }
      },
      true
    );
    translate.use('en');

    fixture = TestBed.createComponent(CropListStagesPanelComponent);
    fixture.componentRef.setInput('cropId', referenceCrop.id);
    presenter = fixture.debugElement.injector.get(CropListStagesPanelPresenter);
    fixture.detectChanges();
  });

  it('shows readonly notice for reference crops when user is not admin', () => {
    presenter.present({ crop: referenceCrop });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Reference crop stages are read-only.');
    expect(fixture.nativeElement.querySelector('.crop-list-panel__stage-name')?.textContent?.trim()).toBe(
      'Seedling'
    );
  });
});
