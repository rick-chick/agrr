import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AgriculturalTaskDetailComponent } from './agricultural-task-detail.component';
import { LoadAgriculturalTaskDetailUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-detail.usecase';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { AgriculturalTaskDetailPresenter } from '../../../usecase/agricultural-tasks/agricultural-task-detail.providers';

describe('AgriculturalTaskDetailComponent', () => {
  let fixture: ComponentFixture<AgriculturalTaskDetailComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AgriculturalTaskDetailComponent, TranslateModule.forRoot()],
      providers: [
        AgriculturalTaskDetailPresenter,
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { paramMap: { get: () => '1' } } }
        },
        { provide: LoadAgriculturalTaskDetailUseCase, useValue: { execute: vi.fn() } },
        { provide: DeleteAgriculturalTaskUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(AgriculturalTaskDetailComponent, {
        set: {
          providers: [
            { provide: LoadAgriculturalTaskDetailUseCase, useValue: { execute: vi.fn() } },
            { provide: DeleteAgriculturalTaskUseCase, useValue: { execute: vi.fn() } }
          ]
        }
      })
      .compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      agricultural_tasks: {
        show: {
          name: 'Name',
          region: 'Region',
          edit: 'Edit',
          back_to_list: 'Back',
          delete: 'Delete'
        },
        form: {
          region_jp: 'Japan',
          region_us: 'United States',
          region_in: 'India'
        }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(AgriculturalTaskDetailComponent);
  });

  it('displays translated region label and value instead of raw region code', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      agriculturalTask: {
        id: 1,
        name: 'Weeding',
        required_tools: [],
        is_reference: false,
        region: 'jp'
      }
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Region');
    expect(text).toContain('Japan');
    expect(text).not.toContain('region_jp');
    expect(text).not.toMatch(/\bregion:\s*jp\b/i);
  });
});
