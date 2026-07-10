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
  let loadExecute: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    loadExecute = vi.fn();
    await TestBed.configureTestingModule({
      imports: [FertilizeEditComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        FertilizeEditPresenter,
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => '5' } } } },
        { provide: LoadFertilizeForEditUseCase, useValue: { execute: loadExecute } },
        { provide: UpdateFertilizeUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: vi.fn(() => ({ admin: true })) } }
      ]
    })
      .overrideComponent(FertilizeEditComponent, {
        set: {
          providers: [
            { provide: LoadFertilizeForEditUseCase, useValue: { execute: loadExecute } },
            { provide: UpdateFertilizeUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

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

  it('shows i18n load error panel with back link and retry on API failure', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      fertilizes: { index: { title: 'Fertilizers' } },
      'common.api_error.not_found': 'Resource not found',
      'masters.load_error.retry': 'Reload'
    });
    translate.use('en');
    component.control = {
      loading: false,
      saving: false,
      error: 'common.api_error.not_found',
      pendingErrorFlash: null,
      formData: {
        name: '',
        n: null,
        p: null,
        k: null,
        description: null,
        package_size: null,
        region: null
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-load-error')?.textContent).toContain(
      'Resource not found'
    );
    expect(
      (fixture.nativeElement.querySelector('a.master-load-error__back') as HTMLAnchorElement)?.getAttribute(
        'href'
      )
    ).toBe('/fertilizes');
  });

  it('reloads edit form when retry is clicked after load error', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      fertilizes: { index: { title: 'Fertilizers' } },
      'common.api_error.generic': 'An error occurred',
      'masters.load_error.retry': 'Reload'
    });
    translate.use('en');
    fixture.detectChanges();
    component.control = {
      loading: false,
      saving: false,
      error: 'common.api_error.generic',
      pendingErrorFlash: null,
      formData: {
        name: '',
        n: null,
        p: null,
        k: null,
        description: null,
        package_size: null,
        region: null
      }
    };
    fixture.detectChanges();

    loadExecute.mockClear();
    fixture.nativeElement.querySelector('.master-load-error__retry')?.click();

    expect(loadExecute).toHaveBeenCalledWith({ fertilizeId: 5 });
  });
});
