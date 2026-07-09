import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';

import { FertilizeDetailComponent } from './fertilize-detail.component';
import { LoadFertilizeDetailUseCase } from '../../../usecase/fertilizes/load-fertilize-detail.usecase';
import { FertilizeDetailPresenter } from '../../../usecase/fertilizes/fertilize-detail.providers';

describe('FertilizeDetailComponent', () => {
  let fixture: ComponentFixture<FertilizeDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FertilizeDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        FertilizeDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: LoadFertilizeDetailUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(FertilizeDetailComponent, {
        set: {
          providers: [
            { provide: LoadFertilizeDetailUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(FertilizeDetailComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      fertilizes: {
        form: {
          region_label: 'Region',
          region_jp: 'Japan',
          region_us: 'United States',
          region_in: 'India'
        }
      }
    });
    translate.use('en');
  });

  it('renders translated region label instead of raw region code', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      fertilize: {
        id: 1,
        name: 'NPK 10-10-10',
        region: 'jp',
        is_reference: false
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Japan');
    expect(el.textContent).not.toContain('region_jp');
  });

  it('shows master context header and omits back button from detail-card__actions', () => {
    translate.setTranslation('en', {
      fertilizes: {
        index: { title: 'Fertilizers' },
        show: { edit: 'Edit' },
        form: {
          region_label: 'Region',
          region_jp: 'Japan'
        }
      }
    });
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      fertilize: {
        id: 1,
        name: 'NPK 10-10-10',
        region: 'jp',
        is_reference: false
      }
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/fertilizes');
    expect(backLink?.textContent?.trim()).toContain('Fertilizers');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'NPK 10-10-10'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
