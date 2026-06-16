import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { ActivatedRoute } from '@angular/router';
import { vi } from 'vitest';
import { PesticideDetailComponent } from './pesticide-detail.component';
import { LoadPesticideDetailUseCase } from '../../../usecase/pesticides/load-pesticide-detail.usecase';
import { DeletePesticideUseCase } from '../../../usecase/pesticides/delete-pesticide.usecase';
import { PesticideDetailPresenter } from '../../../usecase/pesticides/pesticide-detail.providers';

describe('PesticideDetailComponent', () => {
  let component: PesticideDetailComponent;
  let fixture: ComponentFixture<PesticideDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PesticideDetailComponent, TranslateModule.forRoot()],
      providers: [
        PesticideDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: LoadPesticideDetailUseCase, useValue: { execute: vi.fn() } },
        { provide: DeletePesticideUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(PesticideDetailComponent, {
        set: {
          providers: [
            { provide: LoadPesticideDetailUseCase, useValue: { execute: vi.fn() } },
            { provide: DeletePesticideUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(PesticideDetailComponent);
    component = fixture.componentInstance;
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      pesticides: {
        fallback: {
          crop: 'Crop (ID:{{id}})',
          pest: 'Pest (ID:{{id}})'
        }
      }
    });
    translate.use('en');
  });

  it('displays API crop_name and pest_name when present', () => {
    component.control = {
      loading: false,
      error: null,
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false,
        crop_name: 'Tomato',
        pest_name: 'Aphid'
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Tomato');
    expect(el.textContent).toContain('Aphid');
    expect(el.textContent).not.toContain('Crop (ID:51)');
    expect(el.textContent).not.toContain('Pest (ID:54)');
  });

  it('falls back to translated ID label when names are missing', () => {
    component.control = {
      loading: false,
      error: null,
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Crop (ID:51)');
    expect(el.textContent).toContain('Pest (ID:54)');
  });
});
