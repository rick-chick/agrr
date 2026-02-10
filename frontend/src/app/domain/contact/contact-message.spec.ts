import {
  validateEmail,
  validatePayload,
  isValidationFailure
} from './contact-message.model';

describe('ContactMessage domain validation', () => {
  it('validates email format correctly', () => {
    expect(validateEmail('a@b.com')).toBe(true);
    expect(validateEmail('invalid-email')).toBe(false);
    expect(validateEmail('')).toBe(false);
    expect(validateEmail(null as any)).toBe(false);
  });

  it('requires message and enforces max lengths', () => {
    const base = {
      name: 'foo',
      email: 'a@b.com',
      subject: 's',
      source: null,
      message: ''
    };
    const res1 = validatePayload(base as any);
    expect(res1.valid).toBe(false);
    if (isValidationFailure(res1)) {
      expect(res1.message).toBe('contact_form.validation.message_required');
    }

    const longMessage = 'a'.repeat(5001);
    const res2 = validatePayload({ ...base, message: longMessage } as any);
    expect(res2.valid).toBe(false);
    if (isValidationFailure(res2)) {
      expect(res2.message).toBe('contact_form.validation.message_too_long');
    }

    const ok = validatePayload({ ...base, message: 'hello' } as any);
    expect(ok.valid).toBe(true);
  });
});

