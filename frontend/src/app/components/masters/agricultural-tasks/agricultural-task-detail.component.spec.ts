import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';

import { AgriculturalTaskDetailComponent } from './agricultural-task-detail.component';
import { DeleteAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/delete-agricultural-task.usecase';
import { LoadAgriculturalTaskDetailUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-detail.usecase';
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

    fixture = TestBed.createComponent(AgriculturalTaskDetailComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      agricultural_tasks: {
        show: { region: 'Region' },
        form: { region_jp: 'Japan', region_us: 'United States', region_in: 'India' }
      }
    });
    translate.use('en');
  });

  it('renders translated region label instead of raw region code', () => {
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      agriculturalTask: {
        id: 1,
        name: 'Tilling',
        region: 'jp',
        is_reference: false
      }
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Japan');
    expect(el.textContent).not.toContain('region_jp');
  });
});
