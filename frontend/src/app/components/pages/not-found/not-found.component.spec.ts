import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { NotFoundComponent } from './not-found.component';

describe('NotFoundComponent', () => {
  let fixture: ComponentFixture<NotFoundComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [NotFoundComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

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
});
