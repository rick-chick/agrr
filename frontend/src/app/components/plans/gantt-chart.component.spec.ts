import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { HttpErrorResponse } from '@angular/common/http';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { of, throwError } from 'rxjs';

import { GanttChartComponent } from './gantt-chart.component';
import { PlanService, buildCultivationPlanEndpoint } from '../../services/plans/plan.service';
import { AvailableCropData, CultivationData } from '../../domain/plans/cultivation-plan-data';
describe('GanttChartComponent', () => {
  let component: GanttChartComponent;
  let fixture: ComponentFixture<GanttChartComponent>;
  let planService: PlanService;
  let mobileLayoutMatches = false;

  beforeEach(async () => {
    const planServiceMock = {
      adjustPlan: vi.fn(),
      getPlanData: vi.fn(),
      getPublicPlanData: vi.fn(),
      addCrop: vi.fn(),
      removeCultivation: vi.fn(),
      addField: vi.fn(),
      removeField: vi.fn(),
      buildCultivationPlanEndpoint
    };

    await TestBed.configureTestingModule({
      imports: [
        GanttChartComponent,
        HttpClientTestingModule,
        TranslateModule.forRoot()
      ],
      providers: [
        { provide: PlanService, useValue: planServiceMock }
      ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(GanttChartComponent);
    component = fixture.componentInstance;
    planService = TestBed.inject(PlanService);

    // Configure simple translations required by these tests
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      plans: {
        gantt: {
          no_field_data: '圃場データがありません。',
          no_plan_data: '計画データが読み込まれていません。',
          trash_drop_label: '作付を削除'
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

    it('should call private plan adjust endpoint when planType is private', () => {
      component.planType = 'private';

      planService.adjustPlan = vi.fn().mockReturnValue({
        subscribe: vi.fn()
      });

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(planService.adjustPlan).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/adjust',
        expect.any(Object)
      );
    });

    it('should call public plan adjust endpoint when planType is public', () => {
      component.planType = 'public';

      planService.adjustPlan = vi.fn().mockReturnValue({
        subscribe: vi.fn()
      });

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(planService.adjustPlan).toHaveBeenCalledWith(
        '/api/v1/public_plans/cultivation_plans/7/adjust',
        expect.any(Object)
      );
    });

    it('should update fieldGroups after adjustCultivation succeeds', () => {
      component.planType = 'private';

      // getPlanDataが新しいデータを返すようにモック（start_dateが変更されたデータ）
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
            start_date: '2026-09-15', // 変更された日付
            completion_date: '2026-10-15' // 変更された日付
          }]
        }
      };

      // adjustPlanが成功レスポンスを返すようにモック
      planService.adjustPlan = vi.fn().mockReturnValue(
        of({ success: true, message: '調整が完了しました' })
      );

      // getPlanDataが新しいデータを返すようにモック
      planService.getPlanData = vi.fn().mockReturnValue(of(updatedData));

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

    it('should add a crop via planService and refresh data', () => {
      component.visibleStartDate = new Date('2026-02-01');
      component.visibleEndDate = new Date('2026-08-31');
      const crop: AvailableCropData = {
        id: 99,
        name: 'Sweet Corn',
        variety: 'Hybrid',
        area_per_unit: 5
      };
      component.selectedCrop = crop;

      planService.addCrop = vi.fn().mockReturnValue(of({ success: true }));
      const refreshSpy = vi.spyOn(component as any, 'refreshPlanData').mockImplementation(() => {});

      component.confirmAddCrop();

      expect(planService.addCrop).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/add_crop',
        {
          crop_id: 99,
          display_start_date: '2026-02-01',
          display_end_date: '2026-08-31'
        }
      );
      expect(refreshSpy).toHaveBeenCalledWith(7);
      refreshSpy.mockRestore();
    });

    it('should remove a cultivation using removeCultivation', () => {
      const cultivation = {
        id: 33,
        field_id: 1,
        field_name: 'Field 1',
        crop_name: 'Rice',
        start_date: '2026-01-01',
        completion_date: '2026-01-10'
      } as CultivationData;

      planService.removeCultivation = vi.fn().mockReturnValue(of({ success: true }));
      const refreshSpy = vi.spyOn(component as any, 'refreshPlanData').mockImplementation(() => {});

      component.confirmRemoveCultivation(cultivation);

      expect(planService.removeCultivation).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/adjust',
        { moves: [{ allocation_id: 33, action: 'remove' }] }
      );
      expect(refreshSpy).toHaveBeenCalledWith(7);
      refreshSpy.mockRestore();
    });

    it('should add a new field via planService', () => {
      component.newFieldName = 'New Patch';
      component.newFieldArea = 1.2;
      planService.addField = vi.fn().mockReturnValue(of({ success: true }));
      const refreshSpy = vi.spyOn(component as any, 'refreshPlanData').mockImplementation(() => {});

      component.confirmAddField();

      expect(planService.addField).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/add_field',
        { field_name: 'New Patch', field_area: 1.2 }
      );
      expect(refreshSpy).toHaveBeenCalledWith(7);
      refreshSpy.mockRestore();
    });

    it('should remove an empty field', () => {
      const group = { fieldId: 88, fieldName: 'Empty Field', cultivations: [] } as any;
      planService.removeField = vi.fn().mockReturnValue(of({ success: true }));
      const refreshSpy = vi.spyOn(component as any, 'refreshPlanData').mockImplementation(() => {});

      component.confirmRemoveField(group);

      expect(planService.removeField).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/remove_field/88'
      );
      expect(refreshSpy).toHaveBeenCalledWith(7);
      refreshSpy.mockRestore();
    });
  });

  describe('mobile layout, trash drop, and pointer drop commit', () => {
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
      expect(component.canShiftRangeBackward).toBe(true);
      expect(component.canShiftRangeForward).toBe(true);

      component.shiftVisibleRange(-1);
      const shiftedBack = component.visibleStartDate!;
      expect(shiftedBack.getFullYear()).toBe(2025);
      expect(shiftedBack.getMonth()).toBe(11);
      expect(component.canShiftRangeBackward).toBe(true);
      expect(component.canShiftRangeForward).toBe(true);

      component.shiftVisibleRange(36);
      const shiftedForward = component.visibleStartDate!;
      expect(shiftedForward.getTime()).toBeGreaterThan(planEnd.getTime());
      expect(component.canShiftRangeForward).toBe(true);
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
      planService.adjustPlan = vi.fn().mockReturnValue(of({ success: true }));
      planService.getPlanData = vi.fn().mockReturnValue(of(buildPlanData('2026-01-01', '2027-12-31')));
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).not.toHaveBeenCalled();
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2026-02-01').getTime());
      expect(component.visibleEndDate?.getTime()).toBe(new Date('2026-08-31').getTime());
      expect(component['lastPlanEndTime']).toBe(new Date('2027-12-31').getTime());
      initializeSpy.mockRestore();
    });

    it('resets the visible range when adjust moves plan outside the current window', () => {
      planService.adjustPlan = vi.fn().mockReturnValue(of({ success: true }));
      planService.getPlanData = vi.fn().mockReturnValue(of(buildPlanData('2028-01-01', '2028-12-31')));
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).toHaveBeenCalledTimes(1);
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2028-01-01').getTime());
      expect(component['lastPlanStartTime']).toBe(new Date('2028-01-01').getTime());
      initializeSpy.mockRestore();
    });

    it('keeps the visible range when adjust fails and plan data refresh errors out', () => {
      planService.adjustPlan = vi.fn().mockReturnValue(
        throwError(() => new HttpErrorResponse({ status: 400, statusText: 'Bad Request' }))
      );
      planService.getPlanData = vi.fn().mockReturnValue(of(buildPlanData('2026-01-01', '2026-12-31')));
      const initializeSpy = vi.spyOn(component as any, 'initializeVisibleRange');

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-02-01'));

      expect(initializeSpy).not.toHaveBeenCalled();
      expect(component.visibleStartDate?.getTime()).toBe(new Date('2026-02-01').getTime());
      expect(planService.getPlanData).toHaveBeenCalled();
      initializeSpy.mockRestore();
    });
  });
});