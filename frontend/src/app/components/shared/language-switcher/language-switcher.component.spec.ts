import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { LanguageSwitcherComponent } from './language-switcher.component';

describe('LanguageSwitcherComponent', () => {
  let fixture: ComponentFixture<LanguageSwitcherComponent>;
  let translate: TranslateService;
  const storage = new Map<string, string>();

  beforeEach(async () => {
    storage.clear();
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      },
    });

    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [LanguageSwitcherComponent, TranslateModule.forRoot()],
    }).compileComponents();

    fixture = TestBed.createComponent(LanguageSwitcherComponent);
    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    fixture.detectChanges();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders language switcher with accessible label', () => {
    const trigger = fixture.nativeElement.querySelector('.language-switcher-trigger');
    expect(trigger).toBeTruthy();
    expect(trigger.getAttribute('aria-haspopup')).toBe('listbox');
  });

  it('marks current language with aria-current', () => {
    const trigger = fixture.nativeElement.querySelector('.language-switcher-trigger') as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const selected = fixture.nativeElement.querySelector('[aria-current="true"]');
    expect(selected).toBeTruthy();
    expect(selected.getAttribute('data-lang')).toBe('ja');
  });

  it('switches language via applyAppLang and persists to localStorage', () => {
    const trigger = fixture.nativeElement.querySelector('.language-switcher-trigger') as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const enButton = fixture.nativeElement.querySelector('[data-lang="en"]') as HTMLButtonElement;
    enButton.click();
    fixture.detectChanges();

    expect(translate.currentLang).toBe('en');
    expect(storage.get('agrr.app.lang')).toBe('en');
    expect(document.documentElement.lang).toBe('en');
  });

  it('sets document.documentElement.lang to hi when in is selected', () => {
    const trigger = fixture.nativeElement.querySelector('.language-switcher-trigger') as HTMLButtonElement;
    trigger.click();
    fixture.detectChanges();

    const inButton = fixture.nativeElement.querySelector('[data-lang="in"]') as HTMLButtonElement;
    inButton.click();
    fixture.detectChanges();

    expect(translate.currentLang).toBe('in');
    expect(document.documentElement.lang).toBe('hi');
  });
});
