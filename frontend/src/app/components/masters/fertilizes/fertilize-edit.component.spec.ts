import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { FertilizeEditComponent } from './fertilize-edit.component';
import { FertilizeEditPresenter } from '../../../usecase/fertilizes/fertilize-edit.providers';
import { LoadFertilizeForEditUseCase } from '../../../usecase/fertilizes/load-fertilize-for-edit.usecase';
import { UpdateFertilizeUseCase } from '../../../usecase/fertilizes/update-fertilize.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

describe('FertilizeEditComponent', () => {
  let component: FertilizeEditComponent;
  let fixture: ComponentFixture<FertilizeEditComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FertilizeEditComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        FertilizeEditPresenter,
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => '5' } } } },
        { provide: LoadFertilizeForEditUseCase, useValue: { execute: vi.fn() } },
        { provide: UpdateFertilizeUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: vi.fn(() => ({ admin: true })) } }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(FertilizeEditComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('shows three-level breadcrumb with detail link and omits back from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        fertilizes: { index: { title: 'Fertilizers' } },
        common: { edit: 'Edit' }
      },
      true
    );
    translate.use('en');

    component.control = {
      loading: false,
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: {
        name: 'NPK',
        n: null,
        p: null,
        k: null,
        description: null,
        package_size: null,
        region: null
      }
    };
    fixture.detectChanges();

    const detailLink = fixture.nativeElement.querySelector(
      'a.master-context-header__link'
    ) as HTMLAnchorElement;
    expect(detailLink?.getAttribute('href')).toBe('/fertilizes/5');
    expect(detailLink?.textContent?.trim()).toBe('NPK');
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
