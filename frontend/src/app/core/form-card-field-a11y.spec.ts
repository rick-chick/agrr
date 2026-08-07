import { describe, expect, it } from 'vitest';
import {
  formCardFieldAriaDescribedby,
  formCardFieldAriaInvalid,
  formCardFieldErrorId,
  formCardFieldShowError
} from './form-card-field-a11y';

describe('formCardFieldErrorId', () => {
  it('returns a stable error element id for a field', () => {
    expect(formCardFieldErrorId('name')).toBe('name-error');
    expect(formCardFieldErrorId('crop-name')).toBe('crop-name-error');
  });
});

describe('formCardFieldAriaInvalid', () => {
  it('returns true when the field has an error', () => {
    expect(formCardFieldAriaInvalid(true)).toBe(true);
  });

  it('returns null when the field has no error', () => {
    expect(formCardFieldAriaInvalid(false)).toBeNull();
  });
});

describe('formCardFieldAriaDescribedby', () => {
  it('links the input to the field error element id', () => {
    expect(formCardFieldAriaDescribedby(true, 'name')).toBe('name-error');
  });

  it('returns null when there is no error', () => {
    expect(formCardFieldAriaDescribedby(false, 'name')).toBeNull();
  });
});

describe('formCardFieldShowError', () => {
  it('shows custom field errors immediately', () => {
    expect(
      formCardFieldShowError({ invalid: false }, { customError: 'farms.new.form.coordinates_validation_error' })
    ).toBe(true);
  });

  it('shows required errors after submit or touch', () => {
    const invalid = { invalid: true, touched: false, dirty: false };

    expect(formCardFieldShowError(invalid)).toBe(false);
    expect(formCardFieldShowError(invalid, { submitted: true })).toBe(true);
    expect(formCardFieldShowError({ ...invalid, touched: true })).toBe(true);
    expect(formCardFieldShowError({ ...invalid, dirty: true })).toBe(true);
  });

  it('hides errors for valid controls', () => {
    expect(formCardFieldShowError({ invalid: false, touched: true }, { submitted: true })).toBe(false);
  });
});
