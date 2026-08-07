import { describe, expect, it } from 'vitest';

import {
  formCardAriaDescribedby,
  formCardAriaInvalid,
  formCardFieldErrorId,
  formCardFieldShowsError,
  formCardRequiredValueInvalid
} from './form-card-field-a11y';

describe('formCardFieldA11y', () => {
  describe('formCardFieldErrorId', () => {
    it('returns field id suffixed with -error', () => {
      expect(formCardFieldErrorId('name')).toBe('name-error');
      expect(formCardFieldErrorId('crop-name')).toBe('crop-name-error');
    });
  });

  describe('formCardFieldShowsError', () => {
    it('is true only when form was submitted and field is invalid', () => {
      expect(formCardFieldShowsError(false, true)).toBe(false);
      expect(formCardFieldShowsError(true, false)).toBe(false);
      expect(formCardFieldShowsError(true, true)).toBe(true);
    });
  });

  describe('formCardAriaInvalid', () => {
    it('returns true when error is shown, otherwise null', () => {
      expect(formCardAriaInvalid(true, true)).toBe(true);
      expect(formCardAriaInvalid(false, true)).toBeNull();
      expect(formCardAriaInvalid(true, false)).toBeNull();
    });
  });

  describe('formCardAriaDescribedby', () => {
    it('returns error element id when error is shown, otherwise null', () => {
      expect(formCardAriaDescribedby('name', true, true)).toBe('name-error');
      expect(formCardAriaDescribedby('name', false, true)).toBeNull();
      expect(formCardAriaDescribedby('name', true, false)).toBeNull();
    });
  });

  describe('formCardRequiredValueInvalid', () => {
    it('detects empty required values', () => {
      expect(formCardRequiredValueInvalid(null)).toBe(true);
      expect(formCardRequiredValueInvalid('')).toBe(true);
      expect(formCardRequiredValueInvalid('  ')).toBe(true);
      expect(formCardRequiredValueInvalid('farm')).toBe(false);
      expect(formCardRequiredValueInvalid(Number.NaN)).toBe(true);
      expect(formCardRequiredValueInvalid(35)).toBe(false);
    });
  });
});
