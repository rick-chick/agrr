import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
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
  let loadGanttPlanDataUseCase: { execute: ReturnType<typeof vi.fn> };
  let mobileLayoutMatches = false;

  beforeEach(async () => {
    runGanttPlanMutationUseCase = { execute: vi.fn() };
    loadGanttPlanDataUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [
        GanttChartComponent,
        TranslateModule.forRoot()
      ],
      providers: [
        provideRouter([]),
        ...GANTT_CHART_API_PROVIDERS,
        { provide: GANTT_PLAN_GATEWAY, useValue: {} },
        { provide: RunGanttPlanMutationUseCase, useValue: runGanttPlanMutationUseCase },
        { provide: LoadGanttPlanDataUseCase, useValue: loadGanttPlanDataUseCase }
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
          empty_state: {
            reload: '再読み込み',
            add_field: '圃場を追加',
            register_crop: '作物を登録'
          },
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
      },
      common: {
        delete: '削除',
        cancel: 'キャンセル'
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
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
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
      expect(messageElement.textContent?.trim()).toContain('圃場データがありません。');
      expect(fixture.nativeElement.querySelector('.no-data-message__add-field')).toBeTruthy();
    });

    it('should not display gantt chart when data is null', () => {
      component.data = null;
      fixture.detectChanges();

      const svgElement = fixture.nativeElement.querySelector('svg');
      expect(svgElement).toBeFalsy();

      const messageElement = fixture.nativeElement.querySelector('.no-data-message');
      expect(messageElement).toBeTruthy();
      expect(messageElement.textContent?.trim()).toContain('計画データが読み込まれていません。');
    });

    it('shows reload CTA when plan data is missing and planId is set', () => {
      component.data = null;
      component.planId = 7;
      fixture.detectChanges();

      const reloadButton = fixture.nativeElement.querySelector(
        '.no-data-message__reload'
      ) as HTMLButtonElement;
      expect(reloadButton).toBeTruthy();
      expect(reloadButton.textContent?.trim()).toBe('再読み込み');

      reloadButton.click();
      expect(loadGanttPlanDataUseCase.execute).toHaveBeenCalledWith({
        planType: 'private',
        planId: 7,
        purpose: 'refresh'
      });
    });

    it('shows add-field CTA in empty field state and opens the field form', () => {
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [],
          cultivations: []
        }
      } as any;
      component['updateChart']();
      fixture.detectChanges();

      const addFieldButton = fixture.nativeElement.querySelector(
        '.no-data-message__add-field'
      ) as HTMLButtonElement;
      expect(addFieldButton).toBeTruthy();
      expect(addFieldButton.textContent?.trim()).toBe('圃場を追加');
      expect(fixture.nativeElement.querySelector('.field-form')).toBeFalsy();

      addFieldButton.click();
      fixture.detectChanges();

      expect(fixture.nativeElement.querySelector('.field-form')).toBeTruthy();
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

  describe('screen reader accessibility', () => {
    const ganttData = {
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

    beforeEach(() => {
      const translate = TestBed.inject(TranslateService);
      translate.setTranslation('ja', {
        plans: {
          gantt: {
            a11y: {
              field_row: '{{index}}. {{fieldName}}（作付 {{cropCount}} 件）',
              cultivation_bar: '{{fieldName}}の{{cropName}}（{{startDate}}〜{{endDate}}）'
            },
            labels: { year: '年' },
            mobile: { field_column_short: '#' }
          }
        },
        shared: { navbar: { farms: '農場' } }
      }, true);
      translate.use('ja');

      component.data = ganttData;
      component['updateChart']();
      fixture.detectChanges();
    });

    it('exposes aria-label on field rows and cultivation bars', () => {
      const fieldRow = fixture.nativeElement.querySelector('.field-row');
      expect(fieldRow?.getAttribute('aria-label')).toContain('Field 1');
      expect(fieldRow?.getAttribute('role')).toBe('group');

      const bar = fixture.nativeElement.querySelector('.cultivation-bar');
      expect(bar?.getAttribute('aria-label')).toContain('Rice');
      expect(bar?.getAttribute('role')).toBe('button');
    });
  });

  describe('screen reader accessibility (selected cultivation)', () => {
    beforeEach(() => {
      const translate = TestBed.inject(TranslateService);
      translate.setTranslation('ja', {
        plans: {
          gantt: {
            a11y: {
              field_row: '{{index}}. {{fieldName}}（作付 {{cropCount}} 件）',
              cultivation_bar: '{{fieldName}}の{{cropName}}（{{startDate}}〜{{endDate}}）'
            },
            labels: { year: '年' },
            mobile: { field_column_short: '#' }
          }
        },
        shared: { navbar: { farms: '農場' } }
      }, true);
      translate.use('ja');

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
      component.selectedCultivationId = 14;
      component['updateChart']();
      fixture.detectChanges();
    });

    it('marks selected cultivation with aria-selected', () => {
      const bar = fixture.nativeElement.querySelector('.cultivation-bar');
      expect(bar?.getAttribute('aria-selected')).toBe('true');
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
      component.deleteConfirmDialogRef = {
        nativeElement: {
          showModal: HTMLDialogElement.prototype.showModal,
          close: HTMLDialogElement.prototype.close
        }
      } as any;
    });

    it('opens delete confirm dialog and does not remove cultivation when cancelled', () => {
      component.confirmRemoveCultivation(cultivation);

      expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
      expect(component.deleteConfirmMessage).toContain('Rice');
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();

      component.cancelDeleteConfirmDialog();
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
    });

    it('removes cultivation when delete confirm dialog is accepted', () => {
      component.confirmRemoveCultivation(cultivation);
      component.confirmDeleteAction();

      expect(runGanttPlanMutationUseCase.execute).toHaveBeenCalledWith({
        planType: 'private',
        planId: 7,
        command: { kind: 'removeCultivation', cultivationId: 33 }
      });
    });

    it('opens delete confirm dialog and does not remove field when cancelled', () => {
      const group = { fieldId: 88, fieldName: 'Empty Field', cultivations: [] } as any;

      component.confirmRemoveField(group);

      expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
      expect(component.deleteConfirmMessage).toContain('Empty Field');
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();

      component.cancelDeleteConfirmDialog();
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
    });

    it('removes field when delete confirm dialog is accepted', () => {
      const group = { fieldId: 88, fieldName: 'Empty Field', cultivations: [] } as any;

      component.confirmRemoveField(group);
      component.confirmDeleteAction();

      expect(runGanttPlanMutationUseCase.execute).toHaveBeenCalledWith({
        planType: 'private',
        planId: 7,
        command: { kind: 'removeField', fieldId: 88 }
      });
    });
  });

  describe('plan mutation stale lock', () => {
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
      component.selectedCrop = { id: 5, name: 'Tomato' } as any;
      component.deleteConfirmDialogRef = {
        nativeElement: {
          showModal: HTMLDialogElement.prototype.showModal,
          close: HTMLDialogElement.prototype.close
        }
      } as any;
      component.engagePlanMutationStaleLock(7);
    });

    it('blocks add-crop mutation while stale lock is engaged', () => {
      component.confirmAddCrop();
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
    });

    it('blocks delete mutation while stale lock is engaged', () => {
      component.confirmRemoveCultivation(cultivation);
      component.confirmDeleteAction();
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
    });

    it('blocks drag adjust mutation while stale lock is engaged', () => {
      (component as any).adjustCultivation(33, 'Field 1', 0, new Date('2026-02-01'));
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
    });

    it('requests plan refresh from stale lock without clearing until data loads', () => {
      component.reloadPlanDataFromStaleLock();

      expect(loadGanttPlanDataUseCase.execute).toHaveBeenCalledWith({
        planType: 'private',
        planId: 7,
        purpose: 'refresh'
      });
      expect(component.planMutationStaleLocked).toBe(true);
    });

    it('clears stale lock when refreshed plan data is applied', () => {
      component.engagePlanMutationStaleLock(7);
      component.applyRefreshedPlanData(component.data!);

      expect(component.planMutationStaleLocked).toBe(false);
    });

    it('does not start drag while stale lock is engaged', () => {
      component.engagePlanMutationStaleLock(7);

      component['onPointerDown'](
        new PointerEvent('pointerdown', { clientX: 100, clientY: 100, pointerId: 1, button: 0 }),
        cultivation
      );

      expect(component.draggedCultivation).toBeNull();
      expect(component.showOptimizationLock).toBe(false);
    });

    it('does not enable optimization overlay when drag would commit during stale lock', () => {
      component.engagePlanMutationStaleLock(7);
      vi.spyOn(component as any, 'resetBarPosition').mockImplementation(() => undefined);
      vi.spyOn(component as any, 'resetVisualState').mockImplementation(() => undefined);
      component['isDragging'] = true;
      component.draggedCultivation = cultivation;
      component['originalFieldIndex'] = 0;
      component['cachedBarBg'] = {
        getAttribute: (attr: string) => {
          if (attr === 'x') return '200';
          if (attr === 'y') return String(component.config.barPadding);
          if (attr === 'data-original-y') return String(component.config.barPadding);
          return '0';
        },
        setAttribute: vi.fn()
      } as unknown as SVGRectElement;

      component['finishPointerDrag'](200, 100);

      expect(component.showOptimizationLock).toBe(false);
      expect(runGanttPlanMutationUseCase.execute).not.toHaveBeenCalled();
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

  describe('field label layout (desktop)', () => {
    beforeEach(() => {
      mobileLayoutMatches = false;
      component.isMobileLayout = false;
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Baseline Field' }],
          cultivations: [{
            id: 14,
            field_id: 1,
            field_name: 'Baseline Field',
            crop_name: 'Rice',
            start_date: '2026-01-01',
            completion_date: '2026-01-31'
          }]
        }
      } as any;

      const mockContainer = document.createElement('div');
      mockContainer.style.width = '800px';
      component['container'] = { nativeElement: mockContainer } as any;
      component['updateChart']();
      fixture.detectChanges();
    });

    it('anchors field labels before the row divider without overlap', () => {
      const fieldLabel = fixture.nativeElement.querySelector('.field-label');
      expect(fieldLabel).toBeTruthy();
      expect(fieldLabel.getAttribute('text-anchor')).toBe('end');

      const labelX = Number(fieldLabel.getAttribute('x'));
      const divider = fixture.nativeElement.querySelector('.field-row line');
      expect(divider).toBeTruthy();
      const dividerX = Number(divider.getAttribute('x1'));
      expect(labelX).toBeLessThan(dividerX);

      const visibleLabel = Array.from(fieldLabel.childNodes)
        .filter((node: ChildNode) => node.nodeType === Node.TEXT_NODE)
        .map((node: ChildNode) => node.textContent?.trim() ?? '')
        .join('');
      expect(visibleLabel).toBe('Baseline Field');
    });

    it('exposes full field name for assistive technologies', () => {
      const title = fixture.nativeElement.querySelector('.field-label title');
      expect(title?.textContent?.trim()).toBe('Baseline Field');
    });
  });

  describe('crop palette empty state', () => {
    beforeEach(() => {
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [],
          available_crops: []
        }
      } as any;
      component.isCropPaletteOpen = true;
      fixture.detectChanges();
    });

    it('shows crop master registration link when palette has no crops', () => {
      const registerLink = fixture.nativeElement.querySelector(
        '.crop-palette__register-crop'
      ) as HTMLAnchorElement;
      expect(registerLink).toBeTruthy();
      expect(registerLink.textContent?.trim()).toBe('作物を登録');
      expect(registerLink.getAttribute('href')).toBe('/crops/new');
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
        expect(actionButtons[0].classList.contains('action-button--secondary')).toBe(true);
        expect(actionButtons[1].classList.contains('action-button--secondary')).toBe(true);
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