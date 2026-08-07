/** form-card フィールドの aria-invalid / aria-describedby 標準パターン */

export function formCardFieldErrorId(fieldId: string): string {
  return `${fieldId}-error`;
}

export function formCardFieldShowsError(formSubmitted: boolean, invalid: boolean): boolean {
  return formSubmitted && invalid;
}

export function formCardAriaInvalid(formSubmitted: boolean, invalid: boolean): true | null {
  return formCardFieldShowsError(formSubmitted, invalid) ? true : null;
}

export function formCardAriaDescribedby(
  fieldId: string,
  formSubmitted: boolean,
  invalid: boolean
): string | null {
  return formCardFieldShowsError(formSubmitted, invalid) ? formCardFieldErrorId(fieldId) : null;
}

export function formCardRequiredValueInvalid(value: unknown): boolean {
  if (value == null) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (typeof value === 'number') return Number.isNaN(value);
  return false;
}

export function formCardShowsRequiredError(formSubmitted: boolean, value: unknown): boolean {
  return formCardFieldShowsError(formSubmitted, formCardRequiredValueInvalid(value));
}

export function formCardAriaInvalidForRequired(formSubmitted: boolean, value: unknown): true | null {
  return formCardAriaInvalid(formSubmitted, formCardRequiredValueInvalid(value));
}

export function formCardAriaDescribedbyForRequired(
  fieldId: string,
  formSubmitted: boolean,
  value: unknown
): string | null {
  return formCardAriaDescribedby(fieldId, formSubmitted, formCardRequiredValueInvalid(value));
}
