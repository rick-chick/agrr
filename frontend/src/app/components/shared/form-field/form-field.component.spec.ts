import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import { FormFieldComponent, FormFieldSelectOption } from './form-field.component';

describe('FormFieldComponent', () => {
  let fixture: ComponentFixture<FormFieldComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FormFieldComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: { form: { required_field: 'This field is required.' } },
      test: {
        label: 'Test Label',
        hint: 'Helper text',
        option_a: 'Option A',
        option_b: 'Option B'
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(FormFieldComponent);
    fixture.componentInstance.inputId = 'test-field';
    fixture.componentInstance.name = 'testField';
    fixture.componentInstance.labelKey = 'test.label';
    fixture.detectChanges();
  });

  it('renders translated label linked to input', () => {
    const label = fixture.nativeElement.querySelector('label.form-card__field');
    const input = fixture.nativeElement.querySelector('#test-field') as HTMLInputElement;
    expect(label?.getAttribute('for')).toBe('test-field');
    expect(label?.querySelector('.form-card__field-label')?.textContent?.trim()).toBe('Test Label');
    expect(input).toBeTruthy();
  });

  it('sets aria-invalid and aria-describedby on required field after submit when empty', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = true;
    fixture.componentInstance.value = '';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#test-field') as HTMLInputElement;
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe('test-field-error');

    const error = fixture.nativeElement.querySelector('#test-field-error');
    expect(error?.textContent?.trim()).toBe('This field is required.');
    expect(error?.getAttribute('role')).toBe('alert');
  });

  it('omits aria-invalid before submit even when required and empty', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = false;
    fixture.componentInstance.value = '';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#test-field') as HTMLInputElement;
    expect(input.getAttribute('aria-invalid')).toBeNull();
    expect(input.getAttribute('aria-describedby')).toBeNull();
    expect(fixture.nativeElement.querySelector('#test-field-error')).toBeNull();
  });

  it('appends describedBy to aria-describedby when error is shown', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = true;
    fixture.componentInstance.value = '';
    fixture.componentInstance.describedBy = 'test-hint';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#test-field') as HTMLInputElement;
    expect(input.getAttribute('aria-describedby')).toBe('test-field-error test-hint');
  });

  it('renders textarea when type is textarea', () => {
    fixture.componentInstance.type = 'textarea';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('textarea#test-field')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('input')).toBeNull();
  });

  it('renders select with translated options when type is select', () => {
    const options: FormFieldSelectOption[] = [
      { value: 'a', labelKey: 'test.option_a' },
      { value: 'b', labelKey: 'test.option_b' }
    ];
    fixture.componentInstance.type = 'select';
    fixture.componentInstance.options = options;
    fixture.detectChanges();

    const select = fixture.nativeElement.querySelector('select#test-field') as HTMLSelectElement;
    expect(select).toBeTruthy();
    expect(select.classList.contains('form-card__select')).toBe(true);
    const optionLabels = Array.from(select.options).map((o) => o.textContent?.trim());
    expect(optionLabels).toEqual(['Option A', 'Option B']);
  });

  it('emits valueChange when input value changes', () => {
    const emitted: string[] = [];
    fixture.componentInstance.valueChange.subscribe((v) => emitted.push(String(v)));

    const input = fixture.nativeElement.querySelector('#test-field') as HTMLInputElement;
    input.value = 'hello';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();

    expect(emitted).toContain('hello');
  });
});
