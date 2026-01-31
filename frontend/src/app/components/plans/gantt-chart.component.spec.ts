import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { TranslateModule } from '@ngx-translate/core';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { of } from 'rxjs';

import { GanttChartComponent } from './gantt-chart.component';
import { PlanService } from '../../services/plans/plan.service';

describe('GanttChartComponent', () => {
  let component: GanttChartComponent;
  let fixture: ComponentFixture<GanttChartComponent>;
  let planService: PlanService;

  beforeEach(async () => {
    const planServiceMock = {
      adjustPlan: vi.fn(),
      getPlanData: vi.fn(),
      getPublicPlanData: vi.fn()
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
  });

  it('should create', () => {
    expect(component).toBeTruthy();
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
      
      // 初期状態のfieldGroupsを記録
      const initialFieldGroups = JSON.parse(JSON.stringify(component.fieldGroups));
      
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
      
      // adjustCultivationを実行
      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));
      
      // RED: fieldGroupsが更新されていない場合、テストが失敗する
      // updateChart()が呼ばれても、fieldGroupsが更新されていない可能性がある
      expect(component.fieldGroups.length).toBeGreaterThan(0);
      
      // fieldGroups内のcultivationsが更新されているか確認
      const fieldGroup = component.fieldGroups.find(g => g.fieldId === 1);
      expect(fieldGroup).toBeDefined();
      if (fieldGroup) {
        const cultivation = fieldGroup.cultivations.find(c => c.id === 14);
        expect(cultivation).toBeDefined();
        if (cultivation) {
          // RED: 更新されていない場合、テストが失敗する
          expect(cultivation.start_date).toBe('2026-09-15');
          expect(cultivation.completion_date).toBe('2026-10-15');
        } else {
          // RED: cultivationが見つからない場合、テストが失敗する
          expect(cultivation).toBeDefined();
        }
      } else {
        // RED: fieldGroupが見つからない場合、テストが失敗する
        expect(fieldGroup).toBeDefined();
      }
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
});