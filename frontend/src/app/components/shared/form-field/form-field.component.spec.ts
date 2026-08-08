import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import { FormFieldComponent } from './form-field.component';

describe('FormFieldComponent', () => {
  let fixture: ComponentFixture<FormFieldComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FormFieldComponent, FormsModule, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: { form: { required_field: 'Required' } },
      test: {
        label: 'Name',
        placeholder: 'Enter name',
        option_a: 'Option A'
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(FormFieldComponent);
    fixture.componentInstance.inputId = 'name';
    fixture.componentInstance.name = 'name';
    fixture.componentInstance.labelKey = 'test.label';
    fixture.detectChanges();
  });

  it('renders translated label linked to control', () => {
    const label = fixture.nativeElement.querySelector('label.form-card__field');
    expect(label?.getAttribute('for')).toBe('name');
    expect(label?.querySelector('.form-card__field-label')?.textContent?.trim()).toBe('Name');
  });

  it('sets aria-invalid and aria-describedby when required field is invalid after submit', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = true;
    fixture.componentInstance.value = '';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#name') as HTMLInputElement;
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe('name-error');
    expect(fixture.nativeElement.querySelector('#name-error')).not.toBeNull();
  });

  it('omits aria-invalid when field is valid', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = true;
    fixture.componentInstance.value = 'farm';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#name') as HTMLInputElement;
    expect(input.getAttribute('aria-invalid')).toBeNull();
    expect(input.getAttribute('aria-describedby')).toBeNull();
    expect(fixture.nativeElement.querySelector('#name-error')).toBeNull();
  });

  it('renders textarea field type', () => {
    fixture.componentInstance.fieldType = 'textarea';
    fixture.componentInstance.inputId = 'description';
    fixture.componentInstance.name = 'description';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('textarea#description')).not.toBeNull();
  });

  it('renders select field type with options', () => {
    fixture.componentInstance.fieldType = 'select';
    fixture.componentInstance.inputId = 'kind';
    fixture.componentInstance.name = 'kind';
    fixture.componentInstance.selectOptions = [{ value: 'a', labelKey: 'test.option_a' }];
    fixture.detectChanges();

    const select = fixture.nativeElement.querySelector('select#kind') as HTMLSelectElement;
    expect(select).not.toBeNull();
    expect(select.classList.contains('form-card__select')).toBe(true);
    expect(select.options.length).toBe(1);
    expect(select.options[0].textContent?.trim()).toBe('Option A');
  });

  it('combines describedBy with error id when both apply', () => {
    fixture.componentInstance.required = true;
    fixture.componentInstance.formSubmitted = true;
    fixture.componentInstance.value = '';
    fixture.componentInstance.describedBy = 'name-hint';
    fixture.detectChanges();

    const input = fixture.nativeElement.querySelector('#name') as HTMLInputElement;
    expect(input.getAttribute('aria-describedby')).toBe('name-hint name-error');
  });
});
