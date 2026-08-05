import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { SkeletonComponent } from './skeleton.component';

describe('SkeletonComponent', () => {
  let fixture: ComponentFixture<SkeletonComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SkeletonComponent]
    }).compileComponents();

    fixture = TestBed.createComponent(SkeletonComponent);
    fixture.detectChanges();
  });

  it('renders a decorative skeleton block hidden from assistive tech', () => {
    const block = fixture.nativeElement.querySelector('.skeleton');
    expect(block).toBeTruthy();
    expect(block.getAttribute('aria-hidden')).toBe('true');
  });

  it('applies variant modifier class for title preset', () => {
    fixture.componentRef.setInput('variant', 'title');
    fixture.detectChanges();

    const block = fixture.nativeElement.querySelector('.skeleton');
    expect(block.classList.contains('skeleton--title')).toBe(true);
  });

  it('uses shimmer animation class by default', () => {
    const block = fixture.nativeElement.querySelector('.skeleton');
    expect(block.classList.contains('skeleton--shimmer')).toBe(true);
  });
});
