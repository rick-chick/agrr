/** Minimal ngModel / AbstractControl shape for form-card field a11y helpers. */
export interface FormCardNgControl {
  invalid?: boolean;
  touched?: boolean;
  dirty?: boolean;
  errors?: Record<string, unknown> | null;
}

export function formCardFieldErrorId(fieldId: string): string {
  return `${fieldId}-error`;
}

export function formCardFieldAriaInvalid(hasError: boolean): true | null {
  return hasError ? true : null;
}

export function formCardFieldAriaDescribedby(
  hasError: boolean,
  fieldId: string
): string | null {
  return hasError ? formCardFieldErrorId(fieldId) : null;
}

export function formCardFieldShowError(
  control: FormCardNgControl | null | undefined,
  options: { submitted?: boolean; customError?: string | null } = {}
): boolean {
  if (options.customError) {
    return true;
  }
  if (!control?.invalid) {
    return false;
  }
  return Boolean(options.submitted || control.touched || control.dirty);
}
