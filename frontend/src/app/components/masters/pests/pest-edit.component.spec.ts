import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { PestEditComponent } from './pest-edit.component';
import { PestEditPresenter } from '../../../usecase/pests/pest-edit.providers';
import { LoadPestForEditUseCase } from '../../../usecase/pests/load-pest-for-edit.usecase';
import { UpdatePestUseCase } from '../../../usecase/pests/update-pest.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

describe('PestEditComponent', () => {
  let component: PestEditComponent;
  let fixture: ComponentFixture<PestEditComponent>;
  let mockActivatedRoute: { snapshot: { paramMap: { get: () => string | null } } };
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockAuthService: { user: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: () => '1'
        }
      }
    };

    mockLoadUseCase = { execute: vi.fn() };
    mockUpdateUseCase = { execute: vi.fn() };
    mockAuthService = { user: vi.fn(() => ({ admin: true, region: 'jp' })) };

    await TestBed.configureTestingModule({
      imports: [PestEditComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        PestEditPresenter,
        provideRouter([]),
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadPestForEditUseCase, useValue: mockLoadUseCase },
        { provide: UpdatePestUseCase, useValue: mockUpdateUseCase },
        { provide: AuthService, useValue: mockAuthService }
      ]
    }).compileComponents();

    TestBed.overrideComponent(PestEditComponent, {
      set: {
        providers: [
          { provide: UpdatePestUseCase, useValue: mockUpdateUseCase },
          { provide: LoadPestForEditUseCase, useValue: mockLoadUseCase },
          { provide: AuthService, useValue: mockAuthService }
        ]
      }
    });

    fixture = TestBed.createComponent(PestEditComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('sets error when pest id is missing', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'pests.errors.invalid_id': 'Invalid pest ID.'
    });
    translate.use('en');
    mockActivatedRoute.snapshot.paramMap.get = () => null;
    component.ngOnInit();
    expect(component.control.error).toBe(translate.instant('pests.errors.invalid_id'));
  });

  it('shows three-level breadcrumb with detail link and omits back from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        pests: { index: { title: 'Pests' } },
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
        name: 'Aphid',
        name_scientific: null,
        family: null,
        order: null,
        description: null,
        occurrence_season: null,
        region: null
      }
    };
    fixture.detectChanges();

    const detailLink = fixture.nativeElement.querySelector(
      'a.master-context-header__link'
    ) as HTMLAnchorElement;
    expect(detailLink?.getAttribute('href')).toBe('/pests/1');
    expect(detailLink?.textContent?.trim()).toBe('Aphid');
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
