import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { GanttMobileActionsMenuComponent } from './gantt-mobile-actions-menu.component';

describe('GanttMobileActionsMenuComponent', () => {
  let fixture: ComponentFixture<GanttMobileActionsMenuComponent>;
  let component: GanttMobileActionsMenuComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [GanttMobileActionsMenuComponent, TranslateModule.forRoot()]
    }).compileComponents();

    fixture = TestBed.createComponent(GanttMobileActionsMenuComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        plans: {
          gantt: {
            mobile: {
              more_actions: 'その他の操作',
              field_legend_button: '圃場一覧'
            }
          }
        },
        js: {
          gantt: {
            add_field_button: '圃場追加',
            crop_palette_cancel: 'キャンセル'
          }
        }
      },
      true
    );
    translate.use('ja');
    fixture.detectChanges();
  });

  it('opens panel with field menu items and aria-controls', () => {
    const trigger = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__trigger'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('.gantt-mobile-actions-menu__panel');
    expect(panel).toBeTruthy();
    expect(trigger.getAttribute('aria-controls')).toBe('gantt-mobile-actions-menu-panel');
    expect(panel?.id).toBe('gantt-mobile-actions-menu-panel');

    const menuItems = panel!.querySelectorAll('[role="menuitem"]');
    expect(menuItems.length).toBe(2);
    expect(menuItems[0].textContent?.trim()).toBe('圃場追加');
    expect(menuItems[1].textContent?.trim()).toBe('圃場一覧');
  });

  it('emits fieldLegendToggle when field legend item is chosen', () => {
    const toggled = vi.fn();
    component.fieldLegendToggle.subscribe(toggled);

    const trigger = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__trigger'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('.gantt-mobile-actions-menu__panel')!;
    const legendItem = panel.querySelectorAll('[role="menuitem"]')[1] as HTMLButtonElement;
    legendItem.click();

    expect(toggled).toHaveBeenCalledTimes(1);
    expect(component.menuOpen).toBe(false);
  });

  it('closes menu on outside click', () => {
    const trigger = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__trigger'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();
    expect(component.menuOpen).toBe(true);

    document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    fixture.detectChanges();

    expect(component.menuOpen).toBe(false);
  });

  it('closes menu on Escape', () => {
    const trigger = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__trigger'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();

    expect(component.menuOpen).toBe(false);
  });

  it('keeps menu open when clicking inside the panel', () => {
    const trigger = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__trigger'
    ) as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector(
      '.gantt-mobile-actions-menu__panel'
    ) as HTMLElement;
    panel.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    fixture.detectChanges();

    expect(component.menuOpen).toBe(true);
  });
});
