import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { FertilizeCreateComponent } from './fertilize-create.component';
import { FertilizeCreatePresenter } from '../../../usecase/fertilizes/fertilize-create.providers';
import { CreateFertilizeUseCase } from '../../../usecase/fertilizes/create-fertilize.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

describe('FertilizeCreateComponent', () => {
  let fixture: ComponentFixture<FertilizeCreateComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FertilizeCreateComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        FertilizeCreatePresenter,
        provideRouter([]),
        { provide: CreateFertilizeUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: vi.fn(() => ({ admin: true })) } }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(FertilizeCreateComponent);
    fixture.detectChanges();
  });

  it('shows master context header and omits back link from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        fertilizes: { index: { title: 'Fertilizers' }, new: { title: 'Add New Fertilizer' } }
      },
      true
    );
    translate.use('en');
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/fertilizes');
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
