import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';

import { ErrorFallbackComponent } from './error-fallback.component';

describe('ErrorFallbackComponent', () => {
  let fixture: ComponentFixture<ErrorFallbackComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ErrorFallbackComponent, TranslateModule.forRoot()]
    }).compileComponents();

    fixture = TestBed.createComponent(ErrorFallbackComponent);
  });

  it('renders fallback message and reload button', () => {
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.querySelector('.page-title')).toBeTruthy();
    expect(compiled.querySelector('.page-section-content')).toBeTruthy();
    expect(compiled.querySelector('button.btn-primary')).toBeTruthy();
  });
});
