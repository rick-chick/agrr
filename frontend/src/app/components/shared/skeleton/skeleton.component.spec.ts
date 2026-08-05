import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { SkeletonComponent } from './skeleton.component';

describe('SkeletonComponent', () => {
  let fixture: ComponentFixture<SkeletonComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SkeletonComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: {
        loading: 'Loading…'
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(SkeletonComponent);
    fixture.detectChanges();
  });

  it('renders card-list variant with default count of 3 skeleton cards', () => {
    const cards = fixture.nativeElement.querySelectorAll('.skeleton-card');
    expect(cards.length).toBe(3);
  });

  it('renders requested number of skeleton cards', () => {
    fixture.componentRef.setInput('count', 5);
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.skeleton-card');
    expect(cards.length).toBe(5);
  });

  it('uses card-list grid layout matching item-card structure', () => {
    const list = fixture.nativeElement.querySelector('.card-list.skeleton-card-list');
    expect(list).toBeTruthy();

    const titleLine = fixture.nativeElement.querySelector('.skeleton-line--title');
    const metaLine = fixture.nativeElement.querySelector('.skeleton-line--meta');
    const actionButtons = fixture.nativeElement.querySelectorAll('.skeleton-button');

    expect(titleLine).toBeTruthy();
    expect(metaLine).toBeTruthy();
    expect(actionButtons.length).toBeGreaterThanOrEqual(2);
  });

  it('exposes loading state to assistive technology', () => {
    const list = fixture.nativeElement.querySelector('.skeleton-card-list');
    expect(list.getAttribute('aria-busy')).toBe('true');
    expect(list.getAttribute('aria-label')).toBe('Loading…');
    expect(list.getAttribute('role')).toBe('status');
  });

  it('marks decorative skeleton elements as aria-hidden', () => {
    const cards = fixture.nativeElement.querySelectorAll('.skeleton-card');
    cards.forEach((card: Element) => {
      expect(card.getAttribute('aria-hidden')).toBe('true');
    });
  });

  it('applies shimmer animation class on skeleton lines', () => {
    const shimmerLine = fixture.nativeElement.querySelector('.skeleton-line');
    expect(shimmerLine.classList.contains('skeleton-shimmer')).toBe(true);
  });
});
