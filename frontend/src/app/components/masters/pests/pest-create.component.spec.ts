import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { PestCreateComponent } from './pest-create.component';
import { PestCreatePresenter } from '../../../usecase/pests/pest-create.providers';
import { CreatePestUseCase } from '../../../usecase/pests/create-pest.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

describe('PestCreateComponent', () => {
  let fixture: ComponentFixture<PestCreateComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PestCreateComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        PestCreatePresenter,
        provideRouter([]),
        { provide: CreatePestUseCase, useValue: { execute: vi.fn() } },
        { provide: AuthService, useValue: { user: vi.fn(() => ({ admin: true })) } }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(PestCreateComponent);
    fixture.detectChanges();
  });

  it('shows master context header and omits back link from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        pests: { index: { title: 'Pests' }, new: { title: 'Add New Pest' } }
      },
      true
    );
    translate.use('en');
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/pests');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Add New Pest'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
