import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { NavDropdownComponent } from './nav-dropdown.component';

describe('NavDropdownComponent', () => {
  let fixture: ComponentFixture<NavDropdownComponent>;

  beforeEach(async () => {
    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [NavDropdownComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    fixture = TestBed.createComponent(NavDropdownComponent);
    fixture.componentInstance.triggerLabelKey = 'nav.menu_more';
    fixture.componentInstance.panelId = 'nav-more-panel';
    fixture.componentInstance.items = [{ link: '/about', labelKey: 'nav.about' }];
    fixture.componentInstance.isOpen = false;
    fixture.detectChanges();
  });

  it('uses design-system button classes on the dropdown trigger', () => {
    const trigger = fixture.nativeElement.querySelector('.nav-dropdown-trigger') as HTMLButtonElement;
    expect(trigger).toBeTruthy();
    expect(trigger.classList.contains('btn')).toBe(true);
    expect(trigger.classList.contains('btn-secondary')).toBe(true);
    expect(trigger.classList.contains('btn-sm')).toBe(true);
  });
});
