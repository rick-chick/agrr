import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { HttpErrorResponse } from '@angular/common/http';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { of, throwError } from 'rxjs';

import { GanttChartComponent } from './gantt-chart.component';
import { GanttPlanCoordinatorService } from '../../services/plans/gantt-plan-coordinator.service';
import { AvailableCropData, CultivationData } from '../../domain/plans/cultivation-plan-data';
import { GANTT_MARGIN_LEFT_MOBILE } from '../../domain/plans/gantt-chart-layout';
describe('GanttChartComponent', () => {
  let component: GanttChartComponent;
  let fixture: ComponentFixture<GanttChartComponent>;
  let ganttPlanCoordinator: GanttPlanCoordinatorService;
  let mobileLayoutMatches = false;

  beforeEach(async () => {
    const coordinatorMock = {
      adjustCultivationMove: vi.fn(),
      loadPlanData: vi.fn().mockReturnValue(of(null)),
      addCrop: vi.fn(),
      removeCultivation: vi.fn(),
      addField: vi.fn(),
      removeField: vi.fn()
    };

    await TestBed.configureTestingModule({
      imports: [
        GanttChartComponent,
        HttpClientTestingModule,
        TranslateModule.forRoot()
      ],
      providers: [
        { provide: GanttPlanCoordinatorService, useValue: coordinatorMock }
      ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(GanttChartComponent);
    component = fixture.componentInstance;
    ganttPlanCoordinator = TestBed.inject(GanttPlanCoordinatorService);

    // Configure simple translations required by these tests
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      plans: {
        gantt: {
          no_field_data: '圃場データがありません。',
          no_plan_data: '計画データが読み込まれていません。',
          trash_drop_label: '作付を削除',
          mobile: {
            field_legend_button: '圃場一覧',
            field_legend_title: '圃場一覧',
            field_legend_item: '{{index}}. {{fieldName}}',
            field_legend_delete: '削除',
            drag_target_field: '移動先: {{index}} — {{fieldName}}',
            field_column_short: '#'
          }
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

  describe('adjustCultivation', () => {
    beforeEach(() => {
      // Mock data setup
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

      component.fieldGroups = [{
        fieldName: 'Field 1',
        fieldId: 1,
        cultivations: []
      }];
    });

    it('should call adjust coordinator for private plans', () => {
      component.planType = 'private';
      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'failure', failure: {} })
      );

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(ganttPlanCoordinator.adjustCultivationMove).toHaveBeenCalledWith({
        planType: 'private',
        planId: 7,
        cultivationId: 14,
        toFieldId: 1,
        newStartDate: expect.any(Date)
      });
    });

    it('should call adjust coordinator for public plans', () => {
      component.planType = 'public';
      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'failure', failure: {} })
      );

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(ganttPlanCoordinator.adjustCultivationMove).toHaveBeenCalledWith({
        planType: 'public',
        planId: 7,
        cultivationId: 14,
        toFieldId: 1,
        newStartDate: expect.any(Date)
      });
    });

    it('should update fieldGroups after adjustCultivation succeeds', () => {
      component.planType = 'private';

      const updatedData = {
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
            start_date: '2026-09-15',
            completion_date: '2026-10-15'
          }]
        }
      };

      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'success', data: updatedData })
      );

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      const fieldGroup = component.fieldGroups.find(g => g.fieldId === 1);
      expect(fieldGroup).toBeDefined();
      const cultivation = fieldGroup!.cultivations.find(c => c.id === 14);
      expect(cultivation).toBeDefined();
      expect(cultivation!.start_date).toBe('2026-09-15');
      expect(cultivation!.completion_date).toBe('2026-10-15');
    });
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

      // updateChartを実行
      component['updateChart']();

      // RED: fieldsが空の場合、fieldGroupsが空になるはず
      expect(component.fieldGroups).toHaveLength(0);

      // RED: config.heightが最小値になるはず（margin.top + margin.bottom = 60 + 12 = 72）
      expect(component.config.height).toBe(72);

      // fixture.detectChanges() を実行してテンプレートを更新
      fixture.detectChanges();

      // GREEN: fieldsが空の場合、SVG要素は表示されず、メッセージが表示される
      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeFalsy();

      // GREEN: メッセージ要素が表示されている
      const messageElement = fixture.nativeElement.querySelector('.no-data-message');
      expect(messageElement).toBeTruthy();
      expect(messageElement.textContent?.trim()).toBe('圃場データがありません。');
    });

    it('should not display gantt chart when data is null', () => {
      // dataをnullに設定
      component.data = null;

      // updateChartを実行
      component['updateChart']();

      // RED: dataがnullの場合、fieldGroupsが空のままのはず
      expect(component.fieldGroups).toHaveLength(0);

      // RED: config.heightが初期値のままのはず（500）
      expect(component.config.height).toBe(500);

      // fixture.detectChanges() を実行してテンプレートを更新
      fixture.detectChanges();

      // GREEN: dataがnullの場合、SVG要素は表示されず、メッセージが表示される
      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeFalsy();

      // GREEN: メッセージ要素が表示されている
      const messageElement = fixture.nativeElement.querySelector('.no-data-message');
      expect(messageElement).toBeTruthy();
      expect(messageElement.textContent?.trim()).toBe('計画データが読み込まれていません。');
    });

    it('should display gantt chart when data is valid', () => {
      // 有効なデータを設定
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

      // updateChartを実行
      component['updateChart']();

      // GREEN: 有効なデータの場合、fieldGroupsに要素が存在するはず
      expect(component.fieldGroups).toHaveLength(1);

      // GREEN: config.heightが適切に計算されるはず（margin.top + rowHeight + margin.bottom = 60 + 68 + 12 = 140）
      expect(component.config.height).toBe(140);

      // fixture.detectChanges() を実行してテンプレートを更新
      fixture.detectChanges();

      // GREEN: SVG要素の高さが適切に設定されているはず
      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeTruthy();
      expect(svgElement.getAttribute('height')).toBe('140');
    });
  });

  describe('crop and field actions', () => {
    beforeEach(() => {
      component.planType = 'private';
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [],
          available_crops: [{
            id: 99,
            name: 'Sweet Corn',
            variety: 'Hybrid',
            area_per_unit: 5
          }]
        }
      } as any;
    });

    it('should add a crop via coordinator and apply refreshed data', () => {
      component.visibleStartDate = new Date('2026-02-01');
      component.visibleEndDate = new Date('2026-08-31');
      const crop: AvailableCropData = {
        id: 99,
        name: 'Sweet Corn',
        variety: 'Hybrid',
        area_per_unit: 5
      };
      component.selectedCrop = crop;

      ganttPlanCoordinator.addCrop = vi.fn().mockReturnValue(
        of({ status: 'success', data: component.data! })
      );
      const applySpy = vi.spyOn(component as any, 'applyRefreshedPlanData').mockImplementation(() => {});

      component.confirmAddCrop();

      expect(ganttPlanCoordinator.addCrop).toHaveBeenCalledWith('private', 7, {
        crop_id: 99,
        display_start_date: '2026-02-01',
        display_end_date: '2026-08-31'
      });
      expect(applySpy).toHaveBeenCalled();
      applySpy.mockRestore();
    });

    it('should remove a cultivation via coordinator', () => {
      const cultivation = {
        id: 33,
        field_id: 1,
        field_name: 'Field 1',
        crop_name: 'Rice',
        start_date: '2026-01-01',
        completion_date: '2026-01-10'
      } as CultivationData;

      ganttPlanCoordinator.removeCultivation = vi.fn().mockReturnValue(
        of({ status: 'success', data: component.data! })
      );
      const applySpy = vi.spyOn(component as any, 'applyRefreshedPlanData').mockImplementation(() => {});

      component.confirmRemoveCultivation(cultivation);

      expect(ganttPlanCoordinator.removeCultivation).toHaveBeenCalledWith('private', 7, 33);
      expect(applySpy).toHaveBeenCalled();
      applySpy.mockRestore();
    });

    it('should add a new field via coordinator', () => {
      component.newFieldName = 'New Patch';
      component.newFieldArea = 1.2;
      ganttPlanCoordinator.addField = vi.fn().mockReturnValue(
        of({ status: 'success', data: component.data! })
      );
      const applySpy = vi.spyOn(component as any, 'applyRefreshedPlanData').mockImplementation(() => {});

      component.confirmAddField();

      expect(ganttPlanCoordinator.addField).toHaveBeenCalledWith('private', 7, {
        field_name: 'New Patch',
        field_area: 1.2
      });
      expect(applySpy).toHaveBeenCalled();
      applySpy.mockRestore();
    });

    it('should remove an empty field via coordinator', () => {
      const group = { fieldId: 88, fieldName: 'Empty Field', cultivations: [] } as any;
      ganttPlanCoordinator.removeField = vi.fn().mockReturnValue(
        of({ status: 'success', data: component.data! })
      );
      const applySpy = vi.spyOn(component as any, 'applyRefreshedPlanData').mockImplementation(() => {});

      component.confirmRemoveField(group);

      expect(ganttPlanCoordinator.removeField).toHaveBeenCalledWith('private', 7, 88);
      expect(applySpy).toHaveBeenCalled();
      applySpy.mockRestore();
    });
  });

  describe('mobile layout and pointer drop wiring', () => {
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

    it('sets isMobileLayout from matchMedia', () => {
      mobileLayoutMatches = true;
      component.ngAfterViewInit();
      expect(component.isMobileLayout).toBe(true);
    });

    it('uses narrow left margin on mobile layout', () => {
      mobileLayoutMatches = true;
      component.ngAfterViewInit();
      expect(component.config.margin.left).toBe(GANTT_MARGIN_LEFT_MOBILE);
    });

    it('toggles field legend open state on mobile', () => {
      component.isMobileLayout = true;
      component.fieldGroups = [
        { fieldId: 1, fieldName: 'North', cultivations: [cultivation] },
        { fieldId: 2, fieldName: 'South', cultivations: [] }
      ];

      expect(component.fieldLegendOpen).toBe(false);
      component.toggleFieldLegend();
      expect(component.fieldLegendOpen).toBe(true);
      expect(component.fieldGroups.filter((g) => g.cultivations.length === 0).length).toBe(1);
    });

    it('shows cultivation delete controls when isMobileLayout is false', () => {
      component.isMobileLayout = false;
      fixture.detectChanges();

      expect(fixture.nativeElement.querySelectorAll('.cultivation-delete-control').length).toBeGreaterThan(0);
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

    it('calls confirmRemoveCultivation when pointerup ends over trash on mobile', () => {
      component.isMobileLayout = true;
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

  describe('visible range navigation', () => {
    beforeEach(() => {
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: []
        }
      } as any;
    });

    it('allows month shifts before and after the stored plan bounds', () => {
      const planStart = new Date('2026-01-01');
      const planEnd = new Date('2026-12-31');
      component['initializeVisibleRange'](planStart, planEnd);

      expect(component.visibleStartDate?.getTime()).toBe(planStart.getTime());

      component.shiftVisibleRange(-1);
      const shiftedBack = component.visibleStartDate!;
      expect(shiftedBack.getFullYear()).toBe(2025);
      expect(shiftedBack.getMonth()).toBe(11);

      component.shiftVisibleRange(36);
      const shiftedForward = component.visibleStartDate!;
      expect(shiftedForward.getTime()).toBeGreaterThan(planEnd.getTime());
    });
  });

  describe('visible range persistence', () => {
    it('keeps the user visible range when the plan end extends', () => {
      const previousStart = new Date('2026-02-01');
      const previousEnd = new Date('2026-08-31');
      component.visibleStartDate = previousStart;
      component.visibleEndDate = previousEnd;
      component['lastPlanStartTime'] = new Date('2026-01-01').getTime();
      component['lastPlanEndTime'] = new Date('2026-12-31').getTime();

      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');
      component['syncVisibleRange'](new Date('2026-01-01'), new Date('2027-12-31'));

      expect(initializeSpy).not.toHaveBeenCalled();
      expect(component.visibleStartDate?.getTime()).toBe(previousStart.getTime());
      expect(component.visibleEndDate?.getTime()).toBe(previousEnd.getTime());
      expect(component['lastPlanEndTime']).toBe(new Date('2027-12-31').getTime());
      initializeSpy.mockRestore();
    });

    it('resets the visible range when it falls outside new plan bounds', () => {
      const previousStart = new Date('2026-02-01');
      const previousEnd = new Date('2026-08-31');
      component.visibleStartDate = previousStart;
      component.visibleEndDate = previousEnd;
      component['lastPlanStartTime'] = new Date('2026-01-01').getTime();
      component['lastPlanEndTime'] = new Date('2026-12-31').getTime();

      const newPlanStart = new Date('2027-01-01');
      const newPlanEnd = new Date('2027-12-31');
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['syncVisibleRange'](newPlanStart, newPlanEnd);

      expect(initializeSpy).toHaveBeenCalledTimes(1);
      expect(component.visibleStartDate?.getTime()).toBe(newPlanStart.getTime());
      expect(component['lastPlanStartTime']).toBe(newPlanStart.getTime());
      initializeSpy.mockRestore();
    });
  });

  describe('adjust operations and visible range', () => {
    const buildPlanData = (startDate: string, endDate: string) => ({
      data: {
        id: 7,
        planning_start_date: startDate,
        planning_end_date: endDate,
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
    } as any);

    beforeEach(() => {
      component.planType = 'private';
      component.data = buildPlanData('2026-01-01', '2026-12-31');
      component.fieldGroups = [{
        fieldName: 'Field 1',
        fieldId: 1,
        cultivations: []
      }];
      const mockContainer = document.createElement('div');
      mockContainer.getBoundingClientRect = () => ({ width: 800 } as DOMRect);
      component['container'] = { nativeElement: mockContainer } as any;
      component.visibleStartDate = new Date('2026-02-01');
      component.visibleEndDate = new Date('2026-08-31');
      component['lastPlanStartTime'] = new Date('2026-01-01').getTime();
      component['lastPlanEndTime'] = new Date('2026-12-31').getTime();
    });

    it('retains the visible range when adjust extends the plan boundary', () => {
      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'success', data: buildPlanData('2026-01-01', '2027-12-31') })
      );
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).not.toHaveBeenCalled();
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2026-02-01').getTime());
      expect(component.visibleEndDate?.getTime()).toBe(new Date('2026-08-31').getTime());
      expect(component['lastPlanEndTime']).toBe(new Date('2027-12-31').getTime());
      initializeSpy.mockRestore();
    });

    it('resets the visible range when adjust moves plan outside the current window', () => {
      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'success', data: buildPlanData('2028-01-01', '2028-12-31') })
      );
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).toHaveBeenCalledTimes(1);
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2028-01-01').getTime());
      expect(component['lastPlanStartTime']).toBe(new Date('2028-01-01').getTime());
      initializeSpy.mockRestore();
    });

    it('keeps the visible range when adjust fails with a message', () => {
      ganttPlanCoordinator.adjustCultivationMove = vi.fn().mockReturnValue(
        of({ status: 'failure', failure: { message: 'bad request' } })
      );
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');
      const failureSpy = vi.spyOn(component as any, 'handleAdjustmentFailure').mockImplementation(() => {});

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).not.toHaveBeenCalled();
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2026-02-01').getTime());
      expect(failureSpy).toHaveBeenCalledWith('bad request');
      initializeSpy.mockRestore();
      failureSpy.mockRestore();
    });
  });
});