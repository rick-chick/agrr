import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { CardListSkeletonComponent } from './card-list-skeleton.component';

describe('CardListSkeletonComponent', () => {
  let fixture: ComponentFixture<CardListSkeletonComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CardListSkeletonComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', { common: { loading: 'Loading…' } });
    translate.use('en');

    fixture = TestBed.createComponent(CardListSkeletonComponent);
    fixture.componentRef.setInput('count', 3);
    fixture.detectChanges();
  });

  it('renders card-list shaped skeleton rows', () => {
    const items = fixture.nativeElement.querySelectorAll('.card-list__item');
    expect(items.length).toBe(3);
    expect(fixture.nativeElement.querySelector('.card-list')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.item-card')).toBeTruthy();
  });

  it('exposes busy state for screen readers', () => {
    const list = fixture.nativeElement.querySelector('.card-list');
    expect(list.getAttribute('aria-busy')).toBe('true');
    expect(list.getAttribute('aria-label')).toBe('Loading…');
  });
});
