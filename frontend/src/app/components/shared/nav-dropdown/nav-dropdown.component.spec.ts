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
  });

  it('uses design-system classes on dropdown trigger', () => {
    fixture.detectChanges();

    const trigger = fixture.nativeElement.querySelector('button.nav-dropdown-trigger') as HTMLButtonElement;
    expect(trigger).toBeTruthy();
    expect(trigger.classList.contains('btn')).toBe(true);
    expect(trigger.classList.contains('btn-secondary')).toBe(true);
    expect(trigger.classList.contains('btn-sm')).toBe(true);
  });
});
