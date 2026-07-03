import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi, describe, it, expect, beforeEach } from 'vitest';

import { GanttChartComponent } from './gantt-chart.component';
import { CultivationData } from '../../domain/plans/cultivation-plan-data';
import { GANTT_PLAN_GATEWAY } from '../../usecase/plans/gantt-plan-gateway';
import { GANTT_CHART_API_PROVIDERS } from '../../usecase/plans/gantt-chart.providers';
import { LoadGanttPlanDataUseCase } from '../../usecase/plans/load-gantt-plan-data.usecase';
import { RunGanttPlanMutationUseCase } from '../../usecase/plans/run-gantt-plan-mutation.usecase';

/**
 * Component tests: template wiring, action bar (desktop/mobile host), desktop pointercancel, trash dropzone.
 * Mobile overflow menu UI → gantt-mobile-actions-menu.component.spec.ts.
 * Domain layout → gantt-chart-layout.spec.ts; gateway HTTP → gantt-plan-api.gateway.spec.ts;
 * presenter mutations → gantt-chart.presenter.spec.ts; use cases → load/run-gantt-plan-mutation.usecase.spec.ts; mobile touch drag → e2e/gantt-mobile-drag.spec.ts.
 */
describe('GanttChartComponent', () => {
  let component: GanttChartComponent;
  let fixture: ComponentFixture<GanttChartComponent>;
  let runGanttPlanMutationUseCase: { execute: ReturnType<typeof vi.fn> };
  let mobileLayoutMatches = false;

  beforeEach(async () => {
    runGanttPlanMutationUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [
        GanttChartComponent,
        TranslateModule.forRoot()
      ],
      providers: [
        ...GANTT_CHART_API_PROVIDERS,
        { provide: GANTT_PLAN_GATEWAY, useValue: {} },
        { provide: RunGanttPlanMutationUseCase, useValue: runGanttPlanMutationUseCase },
        { provide: LoadGanttPlanDataUseCase, useValue: { execute: vi.fn() } }
      ]
    })
      .overrideComponent(GanttChartComponent, { set: { providers: [] } })
    .compileComponents();

    fixture = TestBed.createComponent(GanttChartComponent);
    component = fixture.componentInstance;
    component.ngOnInit();

    // Configure simple translations required by these tests
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      plans: {
        gantt: {
          no_field_data: '圃場データがありません。',
          no_plan_data: '計画データが読み込まれていません。',
          trash_drop_label: '作付を削除',
          range: {
            prev_month: '前月',
            next_month: '次月'
          },
          mobile: {
            field_legend_button: '圃場一覧',
            field_legend_title: '圃場一覧',
            field_legend_item: '{{index}}. {{fieldName}}',
            field_legend_delete: '削除',
            drag_target_field: '移動先: {{index}} — {{fieldName}}',
            field_column_short: '#'
          }
        }
      },
      js: {
        gantt: {
          add_crop_button: '作物を追加',
          add_field_button: '圃場追加',
          crop_palette_cancel: 'キャンセル',
          confirm_delete_crop: '{{crop_name}}を削除しますか？',
          confirm_delete_field: '{{field_name}}を削除しますか？'
        }
      }
    }, true);
    translate.use('ja');

    vi.stubGlobal(
      'matchMedia',
      vi.fn().mockImplementation((query: string) => ({
        matches: mobileLayoutMatches,
        media: query,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn()
      }))
    );
  });

  describe('gantt chart visibility', () => {
    it('should not display gantt chart when fields is empty', () => {
      // fieldsが空のデータを設定
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [], // 空のfields
          cultivations: []
        }
      } as any;

      component['updateChart']();
      fixture.detectChanges();

      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeFalsy();

      const messageElement = fixture.nativeElement.querySelector('.no-data-message');
      expect(messageElement).toBeTruthy();
      expect(messageElement.textContent?.trim()).toBe('圃場データがありません。');
    });

    it('should not display gantt chart when data is null', () => {
      component.data = null;
      fixture.detectChanges();

      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeFalsy();

      const messageElement = fixture.nativeElement.querySelector('.no-data-message');
      expect(messageElement).toBeTruthy();
      expect(messageElement.textContent?.trim()).toBe('計画データが読み込まれていません。');
    });

    it('should display gantt chart when data is valid', () => {
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [{
            id: 14,
            field_id: 1,
            field_name: 'Field 1',
            crop_name: 'Rice',
            start_date: '2026-01-01',
            completion_date: '2026-01-31'
          }]
        }
      } as any;

      component['updateChart']();
      fixture.detectChanges();

      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeTruthy();
    });
  });

  describe('deletion confirmation', () => {
    const cultivation = {
      id: 33,
      field_id: 1,
      field_name: 'Field 1',
      crop_name: 'Rice',
      start_date: '2026-01-01',
      completion_date: '2026-01-10'
    } as CultivationData;

    beforeEach(() => {
      component.planType = 'private';
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [cultivation]
        }
      } as any;
    });

    it('does not remove cultivation when confirm is cancelled', () => {
      vi.stubGlobal('confirm', vi.fn().mockReturnValue(false));

      component.confirmRemoveCultivation(cultivation);

      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
      vi.unstubAllGlobals();
    });

    it('does not remove field when confirm is cancelled', () => {
      vi.stubGlobal('confirm', vi.fn().mockReturnValue(false));
      const group = { fieldId: 88, fieldName: 'Empty Field', cultivations: [] } as any;

      component.confirmRemoveField(group);

      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
      vi.unstubAllGlobals();
    });
  });

  describe('pointer drag (desktop)', () => {
    const cultivation = {
      id: 33,
      field_id: 1,
      field_name: 'Field 1',
      crop_name: 'Rice',
      start_date: '2026-01-01',
      completion_date: '2026-01-31'
    } as CultivationData;

    beforeEach(() => {
      mobileLayoutMatches = false;
      component.planType = 'private';
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [cultivation]
        }
      } as any;

      const mockContainer = document.createElement('div');
      mockContainer.style.width = '800px';
      component['container'] = { nativeElement: mockContainer } as any;
      vi.spyOn(component as any, 'scheduleDetectChanges').mockImplementation(() => {});
      vi.spyOn(component as any, 'resetBarPosition').mockImplementation(() => undefined);
      vi.spyOn(component as any, 'resetVisualState').mockImplementation(() => undefined);
      component['updateChart']();
      component['needsUpdate'] = false;
    });

    it('does not commit adjust on desktop pointercancel after drag', () => {
      component.isMobileLayout = false;
      component['initializeVisibleRange'](new Date('2026-01-01'), new Date('2026-03-31'));

      const params = component.getBarParams(cultivation);
      expect(params).toBeTruthy();

      const adjustSpy = vi
        .spyOn(component as any, 'adjustCultivation')
        .mockImplementation(() => undefined);

      component['onPointerDown'](
        new PointerEvent('pointerdown', { clientX: 100, clientY: 100, pointerId: 1, button: 0 }),
        cultivation
      );
      component['onPointerMove'](
        new PointerEvent('pointermove', { clientX: 120, clientY: 100, pointerId: 1 })
      );
      component['cachedBarBg'] = {
        getAttribute: (attr: string) => {
          if (attr === 'x') return String(params!.x + 20);
          if (attr === 'y') return String(component.config.barPadding);
          if (attr === 'data-original-y') return String(component.config.barPadding);
          return '0';
        },
        setAttribute: vi.fn()
      } as unknown as SVGRectElement;

      component['onPointerCancel'](
        new PointerEvent('pointercancel', { clientX: 120, clientY: 100, pointerId: 1 })
      );

      expect(component['isDragging']).toBe(false);
      expect(adjustSpy).not.toHaveBeenCalled();
      adjustSpy.mockRestore();
    });

    it('calls confirmRemoveCultivation when pointerup ends over trash', () => {
      component.trashDropzone = {
        nativeElement: {
          getBoundingClientRect: () => ({
            left: 0,
            top: 0,
            right: 100,
            bottom: 100,
            width: 100,
            height: 100,
            x: 0,
            y: 0,
            toJSON: () => ({})
          })
        }
      } as any;

      const removeSpy = vi
        .spyOn(component, 'confirmRemoveCultivation')
        .mockImplementation(() => {});

      component['isDragging'] = true;
      component.draggedCultivation = cultivation;
      component['onPointerUp'](
        new PointerEvent('pointerup', { clientX: 50, clientY: 50, pointerId: 2 })
      );

      expect(removeSpy).toHaveBeenCalledWith(cultivation);
      removeSpy.mockRestore();
    });
  });

  describe('action bar', () => {
    describe('visible range controls', () => {
      it('shows month labels on desktop', () => {
        mobileLayoutMatches = false;
        component.ngAfterViewInit();
        fixture.detectChanges();

        const buttons = fixture.nativeElement.querySelectorAll('.range-button');
        expect(buttons.length).toBe(2);
        expect(buttons[0].textContent?.trim()).toContain('前月');
        expect(buttons[1].textContent?.trim()).toContain('次月');
        expect(buttons[0].getAttribute('aria-label')).toBeNull();
        expect(buttons[0].querySelector('.range-button__icon')).toBeNull();
      });

      it('shows chevron icons with aria-label on mobile', () => {
        mobileLayoutMatches = true;
        component.ngAfterViewInit();
        fixture.detectChanges();

        const buttons = fixture.nativeElement.querySelectorAll('.range-button');
        expect(buttons.length).toBe(2);
        expect(buttons[0].getAttribute('aria-label')).toBe('前月');
        expect(buttons[1].getAttribute('aria-label')).toBe('次月');
        expect(buttons[0].classList.contains('range-button--icon')).toBe(true);
        expect(buttons[0].querySelector('.range-button__icon')).toBeTruthy();
        expect(buttons[1].querySelector('.range-button__icon')).toBeTruthy();
        expect(buttons[0].textContent?.trim()).toBe('');
      });
    });

    describe('mobile action bar wiring', () => {
      beforeEach(() => {
        component.data = {
          data: {
            id: 7,
            planning_start_date: '2026-01-01',
            planning_end_date: '2026-12-31',
            fields: [],
            cultivations: []
          }
        } as any;
      });

      it('shows labeled crop and field buttons on desktop without mobile menu host', () => {
        mobileLayoutMatches = false;
        component.isMobileLayout = false;
        fixture.detectChanges();

        const bar = fixture.nativeElement.querySelector('.gantt-action-bar');
        expect(bar.querySelector('app-gantt-mobile-actions-menu')).toBeFalsy();
        expect(bar.querySelector('.gantt-action-bar__crop-primary')).toBeFalsy();

        const actionButtons = bar.querySelectorAll('.action-button');
        expect(actionButtons.length).toBe(2);
        expect(actionButtons[0].textContent?.trim()).toBe('作物を追加');
        expect(actionButtons[1].textContent?.trim()).toBe('圃場追加');
      });

      it('embeds mobile crop icon and actions menu host on mobile', () => {
        mobileLayoutMatches = true;
        component.isMobileLayout = true;
        fixture.detectChanges();

        const bar = fixture.nativeElement.querySelector('.gantt-action-bar');
        expect(bar.querySelector('.gantt-action-bar__crop-primary')).toBeTruthy();
        expect(bar.querySelector('app-gantt-mobile-actions-menu')).toBeTruthy();
      });
    });
  });

});