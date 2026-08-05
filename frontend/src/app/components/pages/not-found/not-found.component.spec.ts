import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Meta } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { NotFoundComponent } from './not-found.component';

describe('NotFoundComponent', () => {
  let fixture: ComponentFixture<NotFoundComponent>;
  let meta: Meta;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [NotFoundComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    meta = TestBed.inject(Meta);
    fixture = TestBed.createComponent(NotFoundComponent);
    fixture.detectChanges();
  });

  it('should render title and home link', () => {
    const el: HTMLElement = fixture.nativeElement;
    const title = el.querySelector('.page-title');
    expect(title).toBeTruthy();
    const link = el.querySelector('a[routerLink="/"]');
    expect(link).toBeTruthy();
  });

  it('sets robots noindex meta when displayed', () => {
    expect(meta.getTag('name="robots"')?.content).toBe('noindex');
  });
});
