import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropCreateComponent } from './crop-create.component';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';
import { CropCreatePresenter } from '../../../usecase/crops/crop-create.providers';
import { CreateCropUseCase } from '../../../usecase/crops/create-crop.usecase';

describe('CropCreateComponent', () => {
  let fixture: ComponentFixture<CropCreateComponent>;
  let mockAuthService: { user: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockAuthService = {
      user: vi.fn(() => ({ admin: true, region: 'us' }))
    };

    await TestBed.configureTestingModule({
      imports: [
        CropCreateComponent,
        RegionSelectComponent,
        TranslateModule.forRoot({ fallbackLang: 'en' })
      ],
      providers: [
        CropCreatePresenter,
        provideRouter([]),
        { provide: CreateCropUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: mockAuthService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(CropCreateComponent);
    fixture.detectChanges();
  });

  it('shows master context header and omits back link from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: { index: { title: 'Crops' }, new: { title: 'Add New Crop' } }
      },
      true
    );
    translate.use('en');
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/crops');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Add New Crop'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
