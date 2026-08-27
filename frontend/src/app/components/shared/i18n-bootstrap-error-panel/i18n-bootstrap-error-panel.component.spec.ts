import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { I18nBootstrapErrorPanelComponent } from './i18n-bootstrap-error-panel.component';
import { I18nBootstrapStateService } from '../../../core/i18n/i18n-bootstrap-state.service';

describe('I18nBootstrapErrorPanelComponent', () => {
  let fixture: ComponentFixture<I18nBootstrapErrorPanelComponent>;
  let state: I18nBootstrapStateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [I18nBootstrapErrorPanelComponent, TranslateModule.forRoot()]
    }).compileComponents();

    state = TestBed.inject(I18nBootstrapStateService);
    state.markFailed('ja');
    fixture = TestBed.createComponent(I18nBootstrapErrorPanelComponent);
    fixture.detectChanges();
  });

  it('shows load failure message and retry button', () => {
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('[role="alert"]')).toBeTruthy();
    expect(compiled.querySelector('.i18n-bootstrap-error__retry')).toBeTruthy();
  });
});
