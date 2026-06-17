import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
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
          providers: [{ provide: LoadFertilizeDetailUseCase, useValue: { execute: vi.fn() } }]
        }
      })
      .compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      fertilizes: {
        show: {
          edit: 'Edit',
          back_to_list: 'Back'
        },
        form: {
          region_label: 'Region',
          region_jp: 'Japan',
          region_us: 'United States',
          region_in: 'India'
        }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(FertilizeDetailComponent);
  });

  it('displays translated region label and value instead of raw region code', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      fertilize: {
        id: 1,
        name: 'NPK Mix',
        is_reference: false,
        region: 'us'
      }
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Region');
    expect(text).toContain('United States');
    expect(text).not.toContain('region_us');
    expect(text).not.toMatch(/\bregion:\s*us\b/i);
  });
});
