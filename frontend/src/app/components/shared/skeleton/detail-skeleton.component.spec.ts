import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { DetailSkeletonComponent } from './detail-skeleton.component';

describe('DetailSkeletonComponent', () => {
  let fixture: ComponentFixture<DetailSkeletonComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DetailSkeletonComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', { common: { loading: 'Loading…' } });
    translate.use('en');

    fixture = TestBed.createComponent(DetailSkeletonComponent);
    fixture.componentRef.setInput('rowCount', 4);
    fixture.detectChanges();
  });

  it('renders detail-card shaped skeleton with title and rows', () => {
    const card = fixture.nativeElement.querySelector('.detail-card.detail-skeleton');
    expect(card).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.skeleton--title')).toBeTruthy();
    expect(fixture.nativeElement.querySelectorAll('.detail-skeleton__row').length).toBe(4);
    expect(fixture.nativeElement.querySelectorAll('.detail-card__actions .skeleton--button').length).toBe(2);
  });

  it('exposes busy state for screen readers', () => {
    const card = fixture.nativeElement.querySelector('.detail-card');
    expect(card.getAttribute('aria-busy')).toBe('true');
    expect(card.getAttribute('aria-label')).toBe('Loading…');
  });

  it('respects rowCount input', () => {
    fixture.componentRef.setInput('rowCount', 2);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('.detail-skeleton__row').length).toBe(2);
  });
});
