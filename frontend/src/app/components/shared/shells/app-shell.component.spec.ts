import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { AppShellComponent } from './app-shell.component';

describe('AppShellComponent', () => {
  let fixture: ComponentFixture<AppShellComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AppShellComponent, TranslateModule.forRoot()],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation('en', {
      'work.hub.title': 'Work hub',
      'work.hub.subtitle': 'Portfolio overview',
    });

    fixture = TestBed.createComponent(AppShellComponent);
    fixture.componentInstance.titleKey = 'work.hub.title';
    fixture.componentInstance.descriptionKey = 'work.hub.subtitle';
  });

  it('renders page-main with vertical title and description', () => {
    fixture.detectChanges();
    const main = fixture.nativeElement.querySelector('.page-main');
    const title = fixture.nativeElement.querySelector('h1.page-title');
    const description = fixture.nativeElement.querySelector('p.page-description');
    expect(main).toBeTruthy();
    expect(title?.textContent?.trim()).toBe('Work hub');
    expect(description?.textContent?.trim()).toBe('Portfolio overview');
  });
});
