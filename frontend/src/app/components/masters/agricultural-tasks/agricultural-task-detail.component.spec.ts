import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
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
        provideRouter([]),
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
      pendingErrorFlash: null,
      agriculturalTask: {
        id: 1,
        name: 'Tilling',
        region: 'jp',
        is_reference: false,
        required_tools: []
      },
      pendingUndoToast: null,
    };
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Japan');
    expect(el.textContent).not.toContain('region_jp');
  });

  it('shows master context header and omits back button from detail-card__actions', () => {
    translate.setTranslation('en', {
      agricultural_tasks: {
        index: { title: 'Tasks' },
        show: { edit: 'Edit', delete: 'Delete', region: 'Region' },
        form: { region_jp: 'Japan' }
      }
    });
    fixture.detectChanges();
    fixture.componentInstance.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      agriculturalTask: {
        id: 1,
        name: 'Tilling',
        region: 'jp',
        is_reference: false,
        required_tools: []
      },
      pendingUndoToast: null
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/agricultural_tasks');
    expect(backLink?.textContent?.trim()).toContain('Tasks');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Tilling'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });
});
